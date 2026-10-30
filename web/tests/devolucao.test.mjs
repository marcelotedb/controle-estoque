// Testes da lógica pura da tela de devolução (Task 9).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarRetiradas } from '../js/devolucao.js';

const retiradas = [
  { numero: 'RET-0001', responsavel: 'Lindomar', local_nome: 'Loja', data_hora: '2026-10-28T10:00:00Z' },
  { numero: 'RET-0002', responsavel: 'Alexandre', local_nome: 'Eldorado', data_hora: '2026-10-29T14:00:00Z' },
];

test('filtrarRetiradas encontra por número', () => {
  const resultado = filtrarRetiradas(retiradas, 'ret-0002');
  assert.deepEqual(resultado.map((r) => r.numero), ['RET-0002']);
});

test('filtrarRetiradas encontra por responsável', () => {
  const resultado = filtrarRetiradas(retiradas, 'lindomar');
  assert.deepEqual(resultado.map((r) => r.numero), ['RET-0001']);
});

test('filtrarRetiradas encontra por local', () => {
  const resultado = filtrarRetiradas(retiradas, 'eldorado');
  assert.deepEqual(resultado.map((r) => r.numero), ['RET-0002']);
});

test('filtrarRetiradas encontra por data no formato AAAA-MM-DD', () => {
  const resultado = filtrarRetiradas(retiradas, '2026-10-28');
  assert.deepEqual(resultado.map((r) => r.numero), ['RET-0001']);
});

test('busca vazia retorna todas as retiradas', () => {
  const resultado = filtrarRetiradas(retiradas, '');
  assert.equal(resultado.length, 2);
});
