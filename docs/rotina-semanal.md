# Rotina de exportação semanal

O plano gratuito do Supabase não faz backup automático do banco. Esta rotina
substitui o backup: uma vez por semana, os dados do estoque são exportados
para três planilhas e guardados no Google Drive.

**Dia e horário:** a definir pelo dono (ponto aberto 5 da especificação).
Recomendado: sempre no mesmo dia, fora do horário de retiradas, para não
interromper o uso do painel.

## Passos

1. **Abrir o painel** (`index.html`) e conferir se há alertas ou pendências
   não resolvidas. Resolver o que for possível antes de exportar.

2. **Rodar o script de exportação**, com as credenciais do projeto Supabase:

   ```bash
   psql "$SUPABASE_DB_URL" \
     -v itens_csv=/caminho/da/pasta/itens.csv \
     -v movimentacoes_csv=/caminho/da/pasta/movimentacoes.csv \
     -v saldos_csv=/caminho/da/pasta/saldos.csv \
     -f scripts/exportar_semana.sql
   ```

   Sem os parâmetros `-v`, os três arquivos são gravados na pasta atual
   (`itens.csv`, `movimentacoes.csv`, `saldos.csv`).

3. **Criar uma pasta com a data** dentro do Google Drive, por exemplo
   `Estoque World/2026-10-30`, e enviar os três arquivos para dentro dela.

4. **Confirmar que os três arquivos abriram corretamente** (em qualquer
   planilha, como Google Sheets ou Excel) antes de encerrar a rotina.

## O que cada arquivo contém

- **itens.csv** — todos os itens cadastrados, com código, nome, categoria,
  localização e quantidade mínima.
- **movimentacoes.csv** — todas as retiradas, devoluções e ajustes dos
  últimos 7 dias, incluindo retiradas ainda **pendentes** de regularização.
- **saldos.csv** — o saldo disponível, em uso e pendente de cada item no
  momento da exportação, e se está em alerta.

## Por que isso importa

Sem essa rotina, uma perda do banco apaga todo o histórico de retiradas e
devoluções, e o controle volta à estaca zero. A exportação semanal garante
que, mesmo nesse caso, os dados dos últimos meses não se perdem.
