-- View de saldos por item (Task 2). Saldos são sempre calculados a partir das movimentações.
-- Regras:
--   disponível = ajustes concluídos + devoluções 'reuso' concluídas - retiradas concluídas
--   em uso     = retiradas concluídas - devoluções concluídas (qualquer condição)
--   pendente   = devoluções 'defeito' concluídas + retiradas ainda 'pendente'
-- Retiradas pendentes não reduzem o disponível até serem regularizadas (Task 4b).

CREATE OR REPLACE VIEW saldos_itens AS
WITH agregado AS (
  SELECT
    i.id AS item_id,
    i.codigo,
    i.nome,
    i.categoria,
    i.localizacao,
    i.quantidade_minima,
    coalesce(sum(CASE
      WHEN m.tipo = 'ajuste'    AND m.status = 'concluida' THEN  m.quantidade
      WHEN m.tipo = 'devolucao' AND m.status = 'concluida' AND m.condicao = 'reuso' THEN  m.quantidade
      WHEN m.tipo = 'retirada'  AND m.status = 'concluida' THEN -m.quantidade
      ELSE 0 END), 0)::integer AS saldo_disponivel,
    coalesce(sum(CASE
      WHEN m.tipo = 'retirada'  AND m.status = 'concluida' THEN  m.quantidade
      WHEN m.tipo = 'devolucao' AND m.status = 'concluida' THEN -m.quantidade
      ELSE 0 END), 0)::integer AS saldo_em_uso,
    coalesce(sum(CASE
      WHEN m.tipo = 'devolucao' AND m.status = 'concluida' AND m.condicao = 'defeito' THEN m.quantidade
      WHEN m.tipo = 'retirada'  AND m.status = 'pendente' THEN m.quantidade
      ELSE 0 END), 0)::integer AS saldo_pendente
  FROM itens i
  LEFT JOIN movimentacoes m ON m.item_id = i.id
  GROUP BY i.id, i.codigo, i.nome, i.categoria, i.localizacao, i.quantidade_minima
)
SELECT
  a.*,
  (a.saldo_disponivel <= a.quantidade_minima) AS em_alerta
FROM agregado a;
