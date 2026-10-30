// Testes da lógica pura da tela de retirada (Task 9).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarItens, filtrarLocais, localExigeConfirmacao, precisaConfirmarUnidade } from '../js/retirada.js';

const itens = [
  { id: '1', codigo: 'A1', nome: 'Parafuso 6mm' },
  { id: '2', codigo: 'A2', nome: 'Conector Azul' },
];

const locais = [
  { id: 'l1', nome: 'Loja', tipo: 'compartilhado', unidade_id: null },
  { id: 'l2', nome: 'Eldorado', tipo: 'exclusivo', unidade_id: 'saga-id' },
];

test('filtrarItens encontra por nome sem diferenciar acento ou caixa', () => {
  const resultado = filtrarItens(itens, 'parafuso');
  assert.deepEqual(resultado.map((i) => i.codigo), ['A1']);
});

test('filtrarItens encontra por código', () => {
  const resultado = filtrarItens(itens, 'a2');
  assert.deepEqual(resultado.map((i) => i.codigo), ['A2']);
});

test('filtrarLocais encontra por trecho do nome, sem diferenciar caixa', () => {
  const resultado = filtrarLocais(locais, 'ELDO');
  assert.deepEqual(resultado.map((l) => l.nome), ['Eldorado']);
});

test('local compartilhado nunca exige confirmação', () => {
  assert.equal(localExigeConfirmacao(locais[0], 'xam-id'), false);
});

test('local exclusivo da mesma unidade não exige confirmação', () => {
  assert.equal(localExigeConfirmacao(locais[1], 'saga-id'), false);
});

test('local exclusivo de outra unidade exige confirmação', () => {
  assert.equal(localExigeConfirmacao(locais[1], 'xam-id'), true);
});

test('mensagem do banco de confirmação de unidade é reconhecida', () => {
  assert.equal(precisaConfirmarUnidade('confirmação necessária: local pertence a outra unidade'), true);
});

test('outras mensagens do banco não disparam a confirmação', () => {
  assert.equal(precisaConfirmarUnidade('saldo insuficiente: disponível 2'), false);
});
