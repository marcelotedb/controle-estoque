# Controle de Estoque — WorldXambioá Informática

Sistema de controle de estoque sob medida: um depósito único (em Xambioá),
usado pelas três unidades (XAM, SAGA, ARA), com painel de alertas, retirada e
devolução, cadastro de itens e locais de uso, e exportação semanal para backup.

## Como usar

- **Painel** (`index.html`): o que está em alerta (abaixo do mínimo) e as
  pendências (retiradas de emergência ainda não regularizadas). Busca por
  nome, código ou localização.
- **Retirada** (`retirada.html`): registra a saída de um item para um local de
  uso. Gera um número `RET-0001`, `RET-0002`…
- **Devolução** (`devolucao.html`): busca a retirada (por número, responsável,
  local ou data) e registra o retorno — para reuso (volta ao disponível) ou
  defeito (fica pendente de conferência).
- **Itens e locais** (`itens.html`): cadastra novos itens e locais de uso, com
  aviso de nomes parecidos antes de criar um duplicado.

Qualquer pessoa com perfil cadastrado pode fazer essas quatro coisas. Só o
dono pode aprovar um ajuste de contagem física (função `aprovar_ajuste`, hoje
só pelo SQL Editor do Supabase — não há tela para isso ainda).

## Contas de acesso

O site exige login (e-mail e senha). Criar uma conta nova é feito pelo dono,
direto no painel do Supabase — não existe tela de "criar usuário" no site, de
propósito, para não abrir essa porta para qualquer visitante:

1. No [painel do Supabase](https://supabase.com/dashboard/project/xcqroneaylqqgspeodib),
   vá em **Authentication → Users → Add user** e cadastre o e-mail e a senha
   da pessoa (marque "Auto Confirm User").
2. Depois, no **SQL Editor**, rode (trocando o e-mail e o papel):

   ```sql
   insert into perfis (usuario_id, papel)
   select id, 'operador' -- ou 'dono'
   from auth.users
   where email = 'pessoa@exemplo.com';
   ```

Sem essa segunda etapa, a pessoa consegue entrar no site, mas nenhuma tela
funciona (mensagem "usuário sem perfil não pode registrar movimentações") —
é a trava de segurança funcionando como esperado.

## Carga inicial (a fazer por quem conhece o estoque de verdade)

Ninguém além de quem está na loja sabe o que tem na prateleira. Pela tela
**Itens e locais**, cadastre:

1. Os locais de uso já conhecidos: Loja, Eldorado, Índios (e qualquer outro
   endereço/cliente recorrente).
2. Cada item da contagem física, com a **quantidade mínima** que faz sentido
   para ele (abaixo disso, o painel mostra alerta).

Depois de cadastrar os itens, lance os saldos iniciais como um ajuste
aprovado (hoje só pelo SQL Editor, função `solicitar_ajuste` seguida de
`aprovar_ajuste` — avise se quiser que isso seja feito junto).

## Backup semanal

O plano gratuito do Supabase não faz backup automático. Toda semana, exporte
itens, movimentações e saldos com `scripts/exportar_semana.sql` e salve os
três CSVs no Google Drive — o passo a passo está em `docs/rotina-semanal.md`.

## Infraestrutura

- **Banco:** Supabase (projeto `xcqroneaylqqgspeodib`), plano gratuito —
  500 MB de banco, 1 GB de arquivos, pausa depois de 1 semana sem uso (abrir o
  site de vez em quando evita a pausa).
- **Site:** publicado no GitHub Pages, pasta `web/`.
- **Segurança:** Row Level Security no banco — cada tabela e função confere
  se quem está chamando tem perfil cadastrado (e se é o dono, quando a ação
  exige). A chave usada no navegador (`web/js/supabase.js`) é a chave
  publicável: ela não precisa ser escondida, porque a segurança está nas
  políticas do banco, não na chave.

## Desenvolvimento

- `db/`: schema, views e funções do banco, com testes em `db/tests/`
  (`bash db/tests/run_suite.sh` roda tudo contra um Postgres local).
- `web/`: o site, com testes de lógica pura em `web/tests/*.test.mjs`
  (`node --test web/tests/*.test.mjs`) e verificações de tela com Playwright
  (`node web/tests/verificar_*.mjs`).
