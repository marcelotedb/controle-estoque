# Controle de Estoque: Especificação de Design

**Data:** 2026-10-30
**Empresa:** WorldXambioá Informática ("World")
**Status:** aguardando revisão do dono antes do plano de implementação

## 1. Objetivo

Substituir o controle visual atual do estoque por um sistema que responda, a qualquer momento:

- o que existe,
- onde está,
- quanto está disponível,
- quanto está em uso fora do depósito,
- quanto está com defeito ou pendente de conferência.

O sistema deve reduzir dois problemas:

1. Ficar sem material quando ele é necessário.
2. Comprar material que já existe.

Ele também deve manter o histórico de quem retirou e devolveu cada item.

## 2. Escopo

**Incluído nesta versão:**

- Cadastro de itens com nome, categoria, localização física, quantidade mínima e código único.
- Registro de retiradas e devoluções, com vínculo entre as duas.
- Destinos com unidade fixa (XAM, SAGA, ARA) e local de uso variável.
- Painel com saldo por item e alerta de estoque mínimo.
- Acesso pelo navegador do computador fixo e do celular.
- Exportação manual semanal dos dados para o Google Drive.

**Fora do escopo nesta versão:**

- Notificações push, e-mail ou WhatsApp para alertas.
- Compras, cotações ou pedidos de compra.
- Integração com o sistema SAGA de faturamento ou com emissão de nota fiscal.
- Múltiplos depósitos. O estoque é único e fica em Xambioá.
- Leitura de código de barras. O código único será impresso ou digitado.
- Cadastro de clientes. Os destinos são unidades e locais de uso.

## 3. Entidades

**Item**
- `codigo`: identificador único, gerado pelo sistema.
- `nome`: nome padronizado.
- `categoria`: Peças, Revenda ou Insumos.
- `localizacao`: texto livre, ex.: "prateleira 2, gaveta 3".
- `quantidade_minima`: definida pelo dono, considerando o tempo de reposição.
- `saldo_disponivel`: calculado.
- `saldo_em_uso`: calculado.
- `saldo_pendente`: calculado (danificado ou aguardando conferência).

**Unidade** (fixa)
- XAM (Xambioá, sede, onde fica o estoque)
- SAGA (São Geraldo do Araguaia)
- ARA (Araguanã)

**Local de uso** (variável)
- `nome`: ex.: Loja, Eldorado, Índios, nome de cliente.
- `tipo`: `exclusivo` (vinculado a uma unidade) ou `compartilhado` (usável por qualquer unidade).
- `unidade`: preenchido somente quando o tipo é exclusivo.
- Criado na primeira vez que for usado, ou cadastrado antes.

**Movimentação**
- `numero`: gerado pelo sistema, formato RET-0001 para retiradas e DEV-0001 para devoluções.
- `tipo`: retirada ou devolução.
- `item`, `quantidade`.
- `unidade` (fixa) e `local_de_uso`.
- `responsavel`: quem retirou ou devolveu.
- `data_hora`: registrada automaticamente.
- `retirada_origem`: obrigatório em devoluções, aponta para a retirada original.
- `condicao` (somente devolução): "reuso" ou "defeito".
- `status`: "concluida" ou "pendente" (retirada que ainda não foi registrada na hora).

## 4. Regras de negócio

**Cadastro**
- Todo item tem código único.
- Antes de criar um item, o sistema mostra itens com nome parecido. A criação só acontece se o usuário confirmar que é item novo.
- Mesmo tratamento para locais de uso: sugerir existentes antes de criar um novo parecido.

**Retirada**
- Toda retirada exige item, quantidade, unidade, local de uso e responsável.
- A quantidade retirada não pode ser maior que o saldo disponível.
- Ao usar um local exclusivo de outra unidade, o sistema avisa e pede confirmação. Não bloqueia.
- Ao usar um local compartilhado, o registro é direto.
- Retirada de emergência pode ser feita pelo celular, a qualquer hora.
- Se não for possível registrar na hora, a retirada entra como "pendente" e deve ser regularizada depois. Pendências aparecem no painel.

**Devolução**
- A devolução é sempre vinculada a uma retirada existente.
- A quantidade devolvida não pode ser maior que o saldo ainda em uso da retirada.
- Devolução em condição de reuso volta ao saldo disponível.
- Devolução com defeito vai para o saldo pendente e não conta como disponível.

**Saldos**
- `saldo_disponivel` = entradas - retiradas concluídas + devoluções em reuso.
- `saldo_em_uso` = retiradas concluídas ainda não devolvidas.
- `saldo_pendente` = itens devolvidos com defeito, ou retiradas marcadas como pendentes.

**Alertas**
- Um item entra em alerta quando `saldo_disponivel` fica menor ou igual a `quantidade_minima`.
- O alerta aparece somente no painel, na tela inicial. Não há notificação externa nesta versão.

**Permissões**
- Todos podem cadastrar itens, locais de uso e registrar retiradas e devoluções.
- Somente o dono pode aprovar exclusões de itens ou movimentações, e ajustes manuais de quantidade.
- Nenhuma movimentação é apagada. Erros são corrigidos por um lançamento de ajuste, aprovado pelo dono.

## 5. Interface

**Painel (tela inicial)**
- Lista de itens em alerta, no topo.
- Lista de retiradas pendentes de regularização.
- Busca por nome, código ou localização.

**Tela de retirada**
- Campos: item (com busca), quantidade, unidade, local de uso (com sugestão), responsável.
- Confirmação com número RET-XXXX gerado.

**Tela de devolução**
- Busca pela retirada: por número, por responsável, por local de uso ou por data.
- Campo de condição: reuso ou defeito.

**Tela de itens**
- Cadastro e edição de item, com verificação de duplicidade.

**Visualização responsiva**
- A mesma página funciona no computador e no celular. Telas pensadas para uso com uma mão no celular.

## 6. Infraestrutura

- **Banco de dados:** Supabase, plano gratuito. Limites relevantes: 500 MB de banco, 1 GB de arquivos, 2 projetos ativos, pausa após 1 semana sem atividade.
- **Aplicação:** página web acessível pelo navegador, com a mesma interface no celular e no computador.
- **Acesso:** login simples por usuário. Cada usuário é identificado em cada movimentação.
- **Backup:** exportação manual semanal (itens, movimentações e saldos) em planilha, salva no Google Drive. O plano gratuito não tem backup automático.

## 7. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Retiradas não registradas, principalmente em emergências | Celular sempre disponível; status "pendente" para regularizar depois; pendências visíveis no painel |
| Projeto pausado por inatividade do Supabase | Uso diário mantém ativo. Se o depósito ficar parado por mais de uma semana, o dono pode migrar para o plano Pro |
| Perda de dados sem backup automático | Exportação semanal manual para o Google Drive, com rotina definida |
| Duplicidade de itens e locais | Verificação de nomes parecidos antes de criar |
| Alerta ignorado por não ser enviado para fora do painel | Rotina de abrir o painel no início e no fim do expediente |
| Retirada de exclusivo de outra unidade | Aviso e confirmação, sem bloqueio |

## 8. Critérios de sucesso

- Em uma semana de uso, 100% das retiradas e devoluções estão registradas (concluídas ou pendentes).
- Nenhuma compra de item que já está disponível no saldo, a partir do primeiro mês.
- Qualquer item pode ser localizado em até 1 minuto pela busca.
- Exportação semanal feita em pelo menos 4 de 4 semanas no primeiro mês.

## 9. Pontos em aberto (a definir com o dono antes do plano)

1. Lista inicial de itens e categorias: será cadastrada a partir do estoque físico atual, em uma contagem inicial.
2. Quantidade mínima de cada item: definida pelo dono, item a item, na contagem inicial.
3. Locais de uso iniciais: Loja, Eldorado, Índios e demais, cadastrados conforme forem aparecendo.
4. Nomes de usuários e acessos: quantas pessoas, e quem é cada uma.
5. Dia e horário da exportação semanal.

## 10. Revisão da especificação

Verificação feita antes de submeter ao dono:

- **Placeholders:** nenhum "TBD" ou "TODO" nas seções 1 a 8. Os pontos em aberto estão isolados na seção 9.
- **Consistência:** o saldo disponível, em uso e pendente é calculado a partir das mesmas movimentações. As regras de devolução (reuso ou defeito) batem com a seção de saldos.
- **Escopo:** cabe em um único plano de implementação. Notificações externas, compras e integração com o SAGA estão explicitamente fora.
- **Ambiguidade:** "pendente" tem um único significado (retirada não registrada na hora ou devolução com defeito), e os dois casos aparecem separados no painel.
