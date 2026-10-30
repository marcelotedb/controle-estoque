# Controle de Estoque Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o controle visual do estoque da World por um sistema web com saldo por item, registro de retiradas e devoluções vinculadas, destinos por unidade e local de uso, e alerta de estoque mínimo no painel.

**Architecture:** Banco Postgres no Supabase (plano gratuito) com a lógica de saldo e as operações críticas (retirada, devolução, ajuste) implementadas como funções SQL, para que a regra fique no banco e não dependa da página. A página é estática (HTML + JavaScript puro + cliente oficial do Supabase), servida pelo GitHub Pages. O acesso é controlado por Row Level Security: qualquer usuário autenticado registra movimentações; só o dono aprova ajustes e exclusões.

**Tech Stack:** Supabase (Postgres 15, Auth, RLS, funções PL/pgSQL, extensão pg_trgm), HTML/CSS/JavaScript sem framework, `@supabase/supabase-js` via CDN, GitHub Pages, Git.

**Spec:** `/home/claude/docs/superpowers/specs/2026-10-30-controle-estoque-design.md`

## Global Constraints

- Plano gratuito do Supabase: 500 MB de banco, 1 GB de arquivos, 2 projetos ativos, pausa após 1 semana sem atividade. Nenhuma tarefa pode depender de recurso pago.
- Interface em português do Brasil, com textos de botões e mensagens exatamente como definidos nas tarefas.
- Saldos são sempre calculados a partir das movimentações. Nunca existe coluna de saldo gravada.
- Nenhuma movimentação é apagada. Correções entram como ajuste aprovado pelo dono.
- Retirada não pode exceder o saldo disponível. Devolução não pode exceder o saldo em uso da retirada de origem.
- Unidades fixas: `XAM`, `SAGA`, `ARA`. Categorias fixas: `Peças`, `Revenda`, `Insumos`. Tipos de local de uso: `exclusivo`, `compartilhado`.
- Condição de devolução: `reuso` ou `defeito`. Status de retirada: `concluida` ou `pendente`.
- Números gerados: `RET-0001` para retiradas, `DEV-0001` para devoluções.
- Chave publicável do Supabase vai no frontend; a segurança depende de RLS, nunca de esconder a chave.

## Review Focus

1. Duas pessoas retirando o último item ao mesmo tempo: a segunda retirada deve ser recusada, nunca deixar o saldo negativo.
2. Devolução de uma retirada já totalmente devolvida: deve ser recusada com mensagem clara.
3. Nome de item com diferença só de maiúsculas, acentos ou espaços: deve aparecer como possível duplicata antes do cadastro.
4. Local de uso exclusivo sem unidade preenchida: deve ser recusado no cadastro do local.
5. Usuário comum tentando aprovar ajuste ou excluir item: deve ser bloqueado pelo banco, não só pela página.

## Interface map

| Arquivo | Responsabilidade |
|---|---|
| `db/01_schema.sql` | Tabelas, tipos fixos (checks), chaves e índices |
| `db/02_saldos.sql` | View `saldos_itens` com saldo disponível, em uso, pendente e alerta |
| `db/03_operacoes.sql` | Funções `registrar_retirada`, `registrar_devolucao`, `verificar_duplicata_item`, `verificar_duplicata_local` |
| `db/04_permissoes.sql` | Tabela `perfis`, função `eh_dono()`, políticas RLS |
| `db/05_ajustes.sql` | Função `solicitar_ajuste` e `aprovar_ajuste` |
| `db/tests/*.sql` | Testes SQL com fixtures e `DO $$ ... RAISE EXCEPTION` em caso de falha |
| `web/index.html` | Painel com alertas e pendências |
| `web/retirada.html` | Tela de retirada |
| `web/devolucao.html` | Tela de devolução |
| `web/itens.html` | Cadastro e busca de itens e locais |
| `web/js/supabase.js` | Cliente Supabase e helpers de chamada |
| `web/css/app.css` | Estilo responsivo (celular primeiro) |
| `scripts/exportar_semana.sql` | Exportação semanal de itens, movimentações e saldos |

---

### Task 0: Repositório e estrutura

**Files:**
- Create: `/home/claude/controle-estoque/README.md`
- Move: spec e plano para `/home/claude/controle-estoque/docs/superpowers/`

**Interfaces:**
- Consumes: nada
- Produces: repositório Git com a estrutura de pastas de `Interface map`

- [ ] **Step 1: Criar o repositório e as pastas**

```bash
mkdir -p /home/claude/controle-estoque/{db/tests,web/js,web/css,scripts,docs/superpowers/specs,docs/superpowers/plans}
cd /home/claude/controle-estoque && git init -b main
```
Expected: "Initialized empty Git repository" e pastas criadas.

- [ ] **Step 2: Mover spec e plano para dentro do repositório**

```bash
mv /home/claude/docs/superpowers/specs/2026-10-30-controle-estoque-design.md /home/claude/controle-estoque/docs/superpowers/specs/
mv /home/claude/docs/superpowers/plans/2026-10-30-controle-estoque.md /home/claude/controle-estoque/docs/superpowers/plans/
```
Expected: os dois arquivos estão em `controle-estoque/docs/superpowers/`.

- [ ] **Step 3: Commit inicial**

```bash
git add -A && git commit -m "docs: adiciona especificação e plano do controle de estoque

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 1: Schema do banco

**Files:**
- Create: `db/01_schema.sql`
- Test: `db/tests/01_schema_test.sql`

**Interfaces:**
- Consumes: nada
- Produces: tabelas `unidades`, `locais_uso`, `itens`, `movimentacoes`, sequências `seq_ret` e `seq_dev`

- [ ] **Step 1: Escrever o teste que falha**

`db/tests/01_schema_test.sql` deve verificar, com `DO $$ ... END $$`:
- inserir item com categoria `Lixo` falha com violação de check;
- inserir local de uso `exclusivo` sem `unidade_id` falha;
- inserir local `compartilhado` com `unidade_id` preenchido falha;
- as três unidades `XAM`, `SAGA`, `ARA` existem após o schema.

- [ ] **Step 2: Rodar o teste e confirmar que falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/01_schema_test.sql`
Expected: erro "relation does not exist".

- [ ] **Step 3: Implementar `db/01_schema.sql`**

Tabelas com os nomes e checks definidos em `Global Constraints`:
- `unidades(id, codigo unique check in ('XAM','SAGA','ARA'), nome)`, com seed das três.
- `locais_uso(id, nome unique, tipo check in ('exclusivo','compartilhado'), unidade_id references unidades nullable, check (tipo='exclusivo') = (unidade_id is not null))`.
- `itens(id, codigo unique, nome, categoria check in ('Peças','Revenda','Insumos'), localizacao text, quantidade_minima int check >= 0, criado_em)`.
- `movimentacoes(id, numero unique, tipo check in ('retirada','devolucao'), item_id references itens, quantidade int check > 0, unidade_id references unidades nullable, local_uso_id references locais_uso nullable, responsavel text, data_hora timestamptz default now(), retirada_origem_id references movimentacoes nullable, condicao check in ('reuso','defeito') nullable, status check in ('concluida','pendente'))`.
- Check: retirada exige `unidade_id` e `local_uso_id`; devolução exige `retirada_origem_id` e `condicao`.
- Sequências `seq_ret` e `seq_dev` para gerar `numero`.

- [ ] **Step 4: Aplicar o schema e rodar o teste**

Run: `psql "$SUPABASE_DB_URL" -f db/01_schema.sql && psql "$SUPABASE_DB_URL" -f db/tests/01_schema_test.sql`
Expected: sem erros e nenhuma exceção levantada pelo teste.

- [ ] **Step 5: Commit**

```bash
git add db/01_schema.sql db/tests/01_schema_test.sql
git commit -m "feat(db): schema inicial com unidades, locais, itens e movimentações

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 2: Saldos por item

**Files:**
- Create: `db/02_saldos.sql`
- Test: `db/tests/02_saldos_test.sql`

**Interfaces:**
- Consumes: tabelas da Task 1
- Produces: view `saldos_itens(item_id, codigo, nome, categoria, saldo_disponivel, saldo_em_uso, saldo_pendente, quantidade_minima, em_alerta)`

- [ ] **Step 1: Escrever o teste com fixture**

Fixture: item com 10 unidades de entrada (movimentação de tipo `devolucao` não serve para entrada; usar um lançamento inicial de entrada). Como o spec não define entrada explícita, a entrada inicial é um `ajuste` aprovado (ver Task 5). Nesta task, o teste insere a entrada diretamente como movimentação `tipo='ajuste'`, sinal positivo. O teste verifica:
- após retirar 4, `saldo_disponivel = 6`, `saldo_em_uso = 4`;
- após devolver 3 em `reuso`, `saldo_disponivel = 9`, `saldo_em_uso = 1`;
- após devolver 1 em `defeito`, `saldo_disponivel = 9`, `saldo_pendente = 1`;
- com `quantidade_minima = 9` e `saldo_disponivel = 9`, `em_alerta = true`.

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/02_saldos_test.sql`
Expected: erro "relation saldos_itens does not exist" (ou ajuste ausente no check da Task 1: adicionar `ajuste` ao check de `tipo` antes deste passo).

- [ ] **Step 3: Implementar `db/02_saldos.sql`**

View que agrega `movimentacoes` por `item_id`:
- `saldo_disponivel` = soma de ajustes + devoluções `reuso` - retiradas `concluida`;
- `saldo_em_uso` = retiradas `concluida` - devoluções (qualquer condição) vinculadas a elas;
- `saldo_pendente` = devoluções `defeito` + retiradas `pendente`;
- `em_alerta` = `saldo_disponivel <= quantidade_minima`.

- [ ] **Step 4: Rodar o teste e confirmar que passa**

Run: `psql "$SUPABASE_DB_URL" -f db/02_saldos.sql && psql "$SUPABASE_DB_URL" -f db/tests/02_saldos_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/02_saldos.sql db/tests/02_saldos_test.sql db/01_schema.sql
git commit -m "feat(db): view de saldos com disponível, em uso, pendente e alerta

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 3: Registrar retirada

**Files:**
- Create: `db/03_operacoes.sql` (função `registrar_retirada`)
- Test: `db/tests/03_retirada_test.sql`

**Interfaces:**
- Consumes: view `saldos_itens` (Task 2), tabelas da Task 1
- Produces: `registrar_retirada(p_item_id uuid, p_quantidade int, p_unidade_codigo text, p_local_uso_id uuid, p_responsavel text, p_confirmar_unidade_diferente boolean default false) returns table(numero text, aviso text)`

- [ ] **Step 1: Escrever os testes**

Casos obrigatórios, cada um em um bloco `DO $$`:
- retirada de 3 com saldo 10 gera `RET-0001` e saldo cai para 7;
- retirada de 11 com saldo 10 levanta exceção com mensagem contendo "saldo insuficiente";
- quantidade 0 ou negativa levanta exceção;
- local `exclusivo` de SAGA usado com unidade XAM sem `p_confirmar_unidade_diferente` levanta exceção com "confirmação necessária";
- o mesmo caso com `p_confirmar_unidade_diferente = true` registra e devolve `aviso` preenchido;
- local `compartilhado` em qualquer unidade registra sem aviso;
- concorrência: duas sessões tentando retirar o último item ao mesmo tempo, uma deve ser recusada com "saldo insuficiente" e o saldo final nunca fica negativo (teste com duas conexões, uma bloqueada pelo `for update`).

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/03_retirada_test.sql`
Expected: "function registrar_retirada does not exist".

- [ ] **Step 3: Implementar `registrar_retirada`**

Dentro de uma transação implícita da função:
- bloquear a linha de `itens` com `select ... for update` para evitar dupla retirada concorrente;
- validar quantidade > 0;
- verificar `saldo_disponivel >= p_quantidade`, senão `raise exception 'saldo insuficiente: disponível %', saldo`;
- buscar a unidade pelo código e o local de uso;
- se o local for `exclusivo` e a unidade não for a dele, exigir `p_confirmar_unidade_diferente`, senão `raise exception 'confirmação necessária: local pertence a outra unidade'`;
- inserir a movimentação com `status='concluida'`, número `'RET-' || lpad(nextval('seq_ret')::text, 4, '0')`;
- retornar número e aviso (`null` quando não houver).

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/03_operacoes.sql && psql "$SUPABASE_DB_URL" -f db/tests/03_retirada_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/03_operacoes.sql db/tests/03_retirada_test.sql
git commit -m "feat(db): função registrar_retirada com trava de saldo e aviso de unidade

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 4: Registrar devolução

**Files:**
- Modify: `db/03_operacoes.sql` (adicionar `registrar_devolucao`)
- Test: `db/tests/04_devolucao_test.sql`

**Interfaces:**
- Consumes: `registrar_retirada` e view `saldos_itens` (Tasks 2 e 3)
- Produces: `registrar_devolucao(p_retirada_numero text, p_quantidade int, p_condicao text, p_responsavel text) returns text` (retorna o número `DEV-XXXX`)

- [ ] **Step 1: Escrever os testes**

Casos obrigatórios:
- devolução de 2 em `reuso` de uma retirada de 5 gera `DEV-0001` e o saldo em uso da retirada cai para 3;
- devolução maior que o saldo em uso da retirada levanta exceção com "excede o saldo em uso";
- devolução de uma retirada já totalmente devolvida levanta exceção com "já devolvida";
- condição fora de `reuso`/`defeito` levanta exceção;
- número de retirada inexistente levanta exceção com "retirada não encontrada".

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/04_devolucao_test.sql`
Expected: "function registrar_devolucao does not exist".

- [ ] **Step 3: Implementar `registrar_devolucao`**

- localizar a retirada pelo `numero` com `for update`;
- calcular o saldo em uso da retirada (quantidade retirada - devoluções já registradas para ela);
- validar quantidade > 0, condição válida e quantidade <= saldo em uso;
- inserir a devolução com `tipo='devolucao'`, `status='concluida'`, `retirada_origem_id` preenchido, número `'DEV-' || lpad(nextval('seq_dev')::text, 4, '0')`.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/03_operacoes.sql && psql "$SUPABASE_DB_URL" -f db/tests/04_devolucao_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/03_operacoes.sql db/tests/04_devolucao_test.sql
git commit -m "feat(db): função registrar_devolucao vinculada à retirada de origem

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 4b: Regularizar retirada pendente

**Files:**
- Modify: `db/03_operacoes.sql` (adicionar `regularizar_retirada_pendente`)
- Test: `db/tests/04b_regularizacao_test.sql`

**Interfaces:**
- Consumes: `registrar_retirada` (Task 3), view `saldos_itens` (Task 2)
- Produces: `regularizar_retirada_pendente(p_numero text, p_responsavel_regularizacao text) returns void`

- [ ] **Step 1: Escrever os testes**

- retirada com `status='pendente'` vira `concluida` e passa a contar no saldo em uso;
- regularizar retirada já `concluida` levanta exceção "não está pendente";
- regularizar retirada inexistente levanta exceção "retirada não encontrada";
- regularizar retirada cujo item não tem mais saldo suficiente levanta exceção "saldo insuficiente" e mantém o status `pendente`.

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/04b_regularizacao_test.sql`
Expected: "function regularizar_retirada_pendente does not exist".

- [ ] **Step 3: Implementar**

- bloquear a retirada com `for update`;
- verificar `status='pendente'`;
- verificar saldo disponível do item suficiente para a quantidade da retirada;
- mudar `status` para `concluida` e registrar `responsavel_regularizacao` (campo adicional em `movimentacoes`, nulo para as demais).

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/03_operacoes.sql && psql "$SUPABASE_DB_URL" -f db/tests/04b_regularizacao_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/03_operacoes.sql db/tests/04b_regularizacao_test.sql
git commit -m "feat(db): regularização de retirada pendente com checagem de saldo

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 5: Ajustes aprovados pelo dono

**Files:**
- Create: `db/05_ajustes.sql`
- Test: `db/tests/05_ajustes_test.sql`

**Interfaces:**
- Consumes: tabela `movimentacoes` (Task 1), `saldos_itens` (Task 2)
- Produces:
  - `solicitar_ajuste(p_item_id uuid, p_quantidade int, p_motivo text, p_responsavel text) returns uuid` (cria movimentação `ajuste` com `status='pendente'`)
  - `aprovar_ajuste(p_ajuste_id uuid) returns void` (muda para `concluida`; só para o dono, verificado via `eh_dono()` da Task 6)

Nota de dependência: esta task usa `eh_dono()`, definido na Task 6. Para executar esta task antes, a Task 6 pode ser feita primeiro ou `eh_dono()` pode ser um stub que retorna `true` nos testes. Recomendado: executar Task 6 antes da Task 5.

- [ ] **Step 1: Escrever os testes**

- `solicitar_ajuste` cria movimentação com `status='pendente'` e não altera o saldo disponível;
- `aprovar_ajuste` feito por não-dono levanta exceção "somente o dono pode aprovar";
- `aprovar_ajuste` feito pelo dono muda o status para `concluida` e o saldo passa a refletir o ajuste;
- aprovar o mesmo ajuste duas vezes levanta exceção "já aprovado".

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/05_ajustes_test.sql`
Expected: "function solicitar_ajuste does not exist".

- [ ] **Step 3: Implementar as duas funções**

- `solicitar_ajuste` insere `tipo='ajuste'`, `status='pendente'`, com `numero` nulo. Só ajustes `concluida` entram no saldo: a view da Task 2 precisa filtrar por `status='concluida'` para o tipo `ajuste`. Atualizar `db/02_saldos.sql` nesta task, se necessário.
- `aprovar_ajuste` verifica `eh_dono()`, verifica que o status atual é `pendente`, e atualiza para `concluida`.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/02_saldos.sql && psql "$SUPABASE_DB_URL" -f db/05_ajustes.sql && psql "$SUPABASE_DB_URL" -f db/tests/05_ajustes_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/05_ajustes.sql db/02_saldos.sql db/tests/05_ajustes_test.sql
git commit -m "feat(db): ajustes com aprovação exclusiva do dono

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 6: Permissões e RLS

**Files:**
- Create: `db/04_permissoes.sql`
- Test: `db/tests/06_rls_test.sql`

**Interfaces:**
- Consumes: todas as tabelas e funções anteriores
- Produces: tabela `perfis(usuario_id uuid primary key references auth.users, papel text check in ('dono','operador'))`, função `eh_dono() returns boolean`, políticas RLS em `itens`, `locais_uso` e `movimentacoes`

- [ ] **Step 1: Escrever os testes**

- Operador consegue inserir em `itens` e `movimentacoes`;
- Operador não consegue `update` em `movimentacoes` com `status` mudando de `pendente` para `concluida`;
- Operador não consegue `delete` em nenhuma tabela de movimentação;
- Dono consegue aprovar ajuste;
- Usuário sem linha em `perfis` não lê nenhuma tabela.

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/06_rls_test.sql`
Expected: falha porque RLS ainda não está habilitado.

- [ ] **Step 3: Implementar**

- `alter table ... enable row level security` em `itens`, `locais_uso`, `movimentacoes`, `unidades`, `perfis`.
- `eh_dono()` como função `security definer` que consulta `perfis` para `auth.uid()`.
- Políticas: `select` para qualquer perfil cadastrado; `insert` para qualquer perfil cadastrado; `update` e `delete` somente via `eh_dono()`; movimentações não recebem `delete` para ninguém.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/04_permissoes.sql && psql "$SUPABASE_DB_URL" -f db/tests/06_rls_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/04_permissoes.sql db/tests/06_rls_test.sql
git commit -m "feat(db): RLS com dono aprovando ajustes e operadores registrando movimentações

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 7: Verificação de duplicidade

**Files:**
- Modify: `db/03_operacoes.sql`
- Test: `db/tests/07_duplicata_test.sql`

**Interfaces:**
- Consumes: tabelas `itens` e `locais_uso` (Task 1)
- Produces:
  - `verificar_duplicata_item(p_nome text) returns table(item_id uuid, nome text, codigo text)`
  - `verificar_duplicata_local(p_nome text) returns table(local_uso_id uuid, nome text)`

Ambas usam `pg_trgm` (`similarity(...) > 0.4`) sobre o nome normalizado (`lower`, sem acentos via `unaccent`, espaços colapsados).

- [ ] **Step 1: Escrever os testes**

- item cadastrado "Parafuso 6mm" aparece para busca "parafuso 6 mm" e para "PARAFUSO 6MM";
- item "Conector Azul" não aparece para "Cabo de rede";
- local "Eldorado" aparece para "El Dorado".

- [ ] **Step 2: Rodar e confirmar falha**

Run: `psql "$SUPABASE_DB_URL" -f db/tests/07_duplicata_test.sql`
Expected: "function verificar_duplicata_item does not exist".

- [ ] **Step 3: Implementar**

- `create extension if not exists pg_trgm; create extension if not exists unaccent;`
- normalização em função auxiliar `normalizar_nome(text)`;
- as duas funções de verificação com limite de 5 resultados ordenados por similaridade.

- [ ] **Step 4: Rodar os testes e confirmar que passam**

Run: `psql "$SUPABASE_DB_URL" -f db/03_operacoes.sql && psql "$SUPABASE_DB_URL" -f db/tests/07_duplicata_test.sql`
Expected: nenhuma exceção.

- [ ] **Step 5: Commit**

```bash
git add db/03_operacoes.sql db/tests/07_duplicata_test.sql
git commit -m "feat(db): verificação de nomes parecidos para itens e locais

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 8: Página do painel (alertas e pendências)

**Files:**
- Create: `web/index.html`, `web/js/supabase.js`, `web/css/app.css`
- Test: verificação manual descrita no Step 4

**Interfaces:**
- Consumes: view `saldos_itens` (Task 2), tabela `movimentacoes` (Task 1)
- Produces: `supabase.js` exporta `cliente` (cliente Supabase com URL e chave publicável) e `chamar(funcao, params)` que retorna `{dados, erro}`

- [ ] **Step 1: Definir o critério de aceite**

Painel exibe, nesta ordem: itens em alerta (saldo disponível <= mínimo), depois pendências (retiradas `pendente` e saldos `pendente` > 0). Cada linha mostra nome, localização, disponível, em uso, pendente e mínimo. Busca filtra por nome, código ou localização.

- [ ] **Step 2: Implementar `web/js/supabase.js`**

Cliente criado com a URL e a chave publicável do projeto. Constantes em um único bloco no topo do arquivo, para trocar quando o projeto for criado.

- [ ] **Step 3: Implementar `web/index.html` e `web/css/app.css`**

Layout responsivo com largura máxima de 480px no celular e 960px no computador. Alertas em destaque vermelho. Sem frameworks.

- [ ] **Step 4: Verificação manual**

Abrir `web/index.html` no navegador do computador e no celular (via GitHub Pages ou servidor local `python3 -m http.server`). Confirmar com dados de fixture (criados na Task 2) que o item em alerta aparece no topo e que a busca filtra corretamente.
Expected: lista de alertas no topo, busca funcionando, layout legível no celular sem rolagem horizontal.

- [ ] **Step 5: Commit**

```bash
git add web/index.html web/js/supabase.js web/css/app.css
git commit -m "feat(web): painel com alertas e pendências

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 9: Telas de retirada e devolução

**Files:**
- Create: `web/retirada.html`, `web/devolucao.html`
- Modify: `web/js/supabase.js` (helpers, se necessário)

**Interfaces:**
- Consumes: `registrar_retirada` (Task 3), `registrar_devolucao` (Task 4), `chamar` (Task 8)
- Produces: nenhuma interface nova para tarefas posteriores

- [ ] **Step 1: Definir o critério de aceite**

Retirada: busca de item, quantidade, unidade (lista fixa XAM/SAGA/ARA), local de uso com sugestões, responsável. Se o local for exclusivo de outra unidade, mostrar diálogo com o aviso antes de confirmar. Ao sucesso, mostrar o número `RET-XXXX` em destaque.

Devolução: busca por número da retirada, responsável, local ou data. Condição `reuso` ou `defeito`. Ao sucesso, mostrar `DEV-XXXX`.

- [ ] **Step 2: Implementar as duas telas**

Chamar as funções via `chamar`. Erros do banco (saldo insuficiente, confirmação necessária, já devolvida) exibidos como mensagem, sem perder os campos preenchidos.

- [ ] **Step 3: Verificação manual**

Executar os quatro cenários da Review Focus que tocam essas telas: retirada além do saldo, devolução além do saldo em uso, devolução de retirada já devolvida, retirada de local exclusivo de outra unidade com confirmação.
Expected: cada cenário mostra a mensagem do banco e não altera o saldo.

- [ ] **Step 4: Commit**

```bash
git add web/retirada.html web/devolucao.html web/js/supabase.js
git commit -m "feat(web): telas de retirada e devolução com mensagens de erro do banco

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 10: Cadastro de itens e locais

**Files:**
- Create: `web/itens.html`

**Interfaces:**
- Consumes: `verificar_duplicata_item` e `verificar_duplicata_local` (Task 7)
- Produces: nenhuma interface nova

- [ ] **Step 1: Definir o critério de aceite**

Cadastro de item: nome, categoria (lista fixa), localização, quantidade mínima. Antes de salvar, chamar `verificar_duplicata_item` e exibir os parecidos; salvar só após confirmação explícita ("Criar mesmo assim"). Mesma lógica para locais de uso, com tipo e unidade (unidade obrigatória se exclusivo).

- [ ] **Step 2: Implementar**

Formulário com campos condicionais: unidade só aparece quando o tipo é `exclusivo`.

- [ ] **Step 3: Verificação manual**

Cadastrar "Parafuso 6mm" e tentar cadastrar "PARAFUSO 6 MM": a segunda tentativa deve mostrar o primeiro e exigir confirmação. Tentar salvar local exclusivo sem unidade: deve ser bloqueado antes de chegar ao banco.

- [ ] **Step 4: Commit**

```bash
git add web/itens.html
git commit -m "feat(web): cadastro de itens e locais com verificação de duplicidade

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 11: Exportação semanal

**Files:**
- Create: `scripts/exportar_semana.sql`
- Create: `docs/rotina-semanal.md`

**Interfaces:**
- Consumes: `itens`, `movimentacoes`, `saldos_itens` (Tasks 1 e 2)
- Produces: três consultas que geram CSV (itens, movimentações, saldos)

- [ ] **Step 1: Escrever a consulta que falha**

Teste: a exportação de movimentações deve conter todas as linhas da semana, incluindo as com `status='pendente'`. Verificar com fixture que a contagem bate.

- [ ] **Step 2: Implementar**

Três `\copy` com `csv header`, filtrando movimentações por `data_hora >= now() - interval '7 days'` na aba de movimentações. Itens e saldos são exportados completos.

- [ ] **Step 3: Documentar a rotina**

`docs/rotina-semanal.md` com passos: abrir o painel, rodar o script, salvar os três arquivos no Google Drive em pasta com a data. Frequência e dia definidos pelo dono (ponto aberto 5 da especificação).

- [ ] **Step 4: Verificação**

Rodar o script contra o banco com fixture e abrir os CSVs gerados. Expected: três arquivos legíveis em UTF-8 com cabeçalho.

- [ ] **Step 5: Commit**

```bash
git add scripts/exportar_semana.sql docs/rotina-semanal.md
git commit -m "feat: exportação semanal de itens, movimentações e saldos

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

### Task 12: Publicação e carga inicial

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: todos os arquivos anteriores
- Produces: site publicado no GitHub Pages e banco com as unidades e locais iniciais

- [ ] **Step 1: Criar o projeto Supabase**

Criar o projeto no plano gratuito. Se a ferramenta pedir confirmação de custo, confirmar que o plano é o gratuito antes de prosseguir.

- [ ] **Step 2: Aplicar todos os scripts na ordem**

Ordem: `01_schema`, `02_saldos`, `03_operacoes`, `04_permissoes`, `05_ajustes`, todos os `tests/*.sql`.
Expected: nenhuma exceção.

- [ ] **Step 3: Publicar no GitHub Pages**

Criar repositório no GitHub, dar push e ativar Pages na branch `main`. Atualizar as constantes de URL e chave em `web/js/supabase.js`.

- [ ] **Step 4: Carga inicial**

Cadastrar, pela tela de itens, os locais de uso conhecidos (Loja, Eldorado, Índios) e os itens da contagem física (ponto aberto 1 da especificação). Definir a quantidade mínima de cada item (ponto aberto 2).

- [ ] **Step 5: Commit**

```bash
git add README.md web/js/supabase.js
git commit -m "docs: README e configuração de publicação

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01EMgdMv1t6uTpoETR8cjKLs"
```

---

## Self-Review

**1. Cobertura da especificação**
- Cadastro com código, categoria, localização, mínimo: Tasks 1 e 10.
- Verificação de duplicidade: Task 7 (funções) e Task 10 (tela).
- Destinos fixos e locais de uso exclusivo/compartilhado com aviso: Tasks 1, 3 e 10.
- Retirada com trava de saldo e número RET: Task 3.
- Devolução vinculada, reuso e defeito: Task 4.
- Retirada pendente: campo `status` na Task 1; regularização na Task 4b; lista no painel na Task 8.
- Painel com alerta e pendências: Task 8.
- Permissões do dono: Tasks 5 e 6.
- Exportação semanal manual: Task 11.
- Celular e computador: Tasks 8 a 10 (layout responsivo).
- Acesso pelo celular em emergência: Task 9.

**Lacuna corrigida:** a regularização de retirada pendente agora é a Task 4b, criada antes do painel (Task 8), que precisa do botão de ação.

**2. Passos**
- Todos os passos têm comando, arquivo ou critério de aceite. Os passos de verificação manual (Tasks 8 a 10) descrevem o cenário e o resultado esperado.

**3. Consistência de tipos**
- `registrar_retirada` retorna `(numero, aviso)`; a tela de retirada da Task 9 usa os dois campos.
- `registrar_devolucao` retorna `text` (número). Consistente com a Task 9.
- `status` usa `concluida` e `pendente` em todas as tasks.
- `eh_dono()` definido na Task 6 e usado na Task 5. Ordem de execução recomendada: Task 6 antes da Task 5, indicada no texto da Task 5.

**4. Review Focus**
- Concorrência de saldo: coberta pelo `for update` da Task 3 e pelo caso de duas conexões incluído no Step 1 da Task 3.
- Devolução de retirada já devolvida: Task 4, caso obrigatório.
- Nome com diferença de caixa e acento: Task 7.
- Local exclusivo sem unidade: Task 1 (check) e Task 10 (validação na tela).
- Operador tentando aprovar ajuste: Task 5 e Task 6.

**5. Proporção:** o plano é proporcional à especificação. Os blocos de código aparecem apenas em comandos; o código das funções fica para o implementador, com assinaturas definidas nas seções Interfaces.

---

## Execution Handoff

Plano salvo em `/home/claude/docs/superpowers/plans/2026-10-30-controle-estoque.md` (será movido para `controle-estoque/docs/superpowers/plans/` na Task 0).

Ponto a confirmar antes da implementação: a publicação usa GitHub Pages, o que exige uma conta no GitHub. Se você não tiver, outra opção gratuita é hospedar o site dentro do próprio Supabase Storage, com as mesmas regras de acesso.

Para a execução, há duas opções:

- **Subagent-driven:** um subagente novo implementa cada tarefa e um revisor independente checa antes da próxima. Mais cuidadoso, porém mais caro, porque cada tarefa e cada revisão começam com contexto novo.
- **Native:** eu implemento todas as tarefas nesta sessão, e no final um revisor independente checa o conjunto. Mais barato e rápido, mas sem revisão independente até o fim.

**Recomendo a opção Native.** As tarefas dependem fortemente umas das outras pelas assinaturas das funções SQL, e a maior parte do trabalho é SQL com testes, o que é fácil de verificar no próprio fluxo. O custo de um erro de regra de estoque em produção é alto, então a revisão final independente é importante nos dois casos.

**Você revisou o plano e quer seguir com qual abordagem?**

- a) Native (recomendado)
- b) Subagent-driven
- c) Quero ajustar o plano antes (me diga o que mudar)

