// Testes da lógica pura do painel (Task 8): separar alertas/pendências e filtrar por busca.
// Lógica separada da chamada de rede para poder ser testada sem um projeto Supabase real.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { separarSecoes, filtrarLinhas } from '../js/painel.js';

const linhas = [
  { codigo: 'A1', nome: 'Parafuso 6mm', localizacao: 'prateleira 1', saldo_disponivel: 2, saldo_em_uso: 0, saldo_pendente: 0, quantidade_minima: 5, em_alerta: true },
  { codigo: 'A2', nome: 'Conector Azul', localizacao: 'prateleira 2', saldo_disponivel: 10, saldo_em_uso: 0, saldo_pendente: 3, quantidade_minima: 2, em_alerta: false },
  { codigo: 'A3', nome: 'Cabo de rede', localizacao: 'prateleira 3', saldo_disponivel: 20, saldo_em_uso: 0, saldo_pendente: 0, quantidade_minima: 1, em_alerta: false },
];

test('alertas aparecem antes de itens sem alerta e sem pendência', () => {
  const { alertas, pendentes, normais } = separarSecoes(linhas);
  assert.deepEqual(alertas.map(l => l.codigo), ['A1']);
  assert.deepEqual(pendentes.map(l => l.codigo), ['A2']);
  assert.deepEqual(normais.map(l => l.codigo), ['A3']);
});

test('item em alerta não aparece duplicado na seção de pendências', () => {
  const comAlertaEPendencia = [
    ...linhas,
    { codigo: 'A4', nome: 'Item alerta e pendente', localizacao: 'x', saldo_disponivel: 1, saldo_em_uso: 0, saldo_pendente: 2, quantidade_minima: 5, em_alerta: true },
  ];
  const { alertas, pendentes } = separarSecoes(comAlertaEPendencia);
  assert.ok(alertas.some(l => l.codigo === 'A4'));
  assert.ok(!pendentes.some(l => l.codigo === 'A4'));
});

test('busca filtra por nome, ignorando maiúsculas e acentos', () => {
  const resultado = filtrarLinhas(linhas, 'parafuso');
  assert.deepEqual(resultado.map(l => l.codigo), ['A1']);
});

test('busca filtra por código', () => {
  const resultado = filtrarLinhas(linhas, 'a2');
  assert.deepEqual(resultado.map(l => l.codigo), ['A2']);
});

test('busca filtra por localização', () => {
  const resultado = filtrarLinhas(linhas, 'prateleira 3');
  assert.deepEqual(resultado.map(l => l.codigo), ['A3']);
});

test('busca vazia retorna todas as linhas', () => {
  const resultado = filtrarLinhas(linhas, '');
  assert.equal(resultado.length, 3);
});
