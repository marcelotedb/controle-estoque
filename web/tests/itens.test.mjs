// Testes da lógica pura do cadastro de itens e locais (Task 10).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { localExclusivoSemUnidade } from '../js/itens.js';

test('local exclusivo sem unidade é bloqueado antes do banco', () => {
  assert.equal(localExclusivoSemUnidade('exclusivo', ''), true);
  assert.equal(localExclusivoSemUnidade('exclusivo', null), true);
});

test('local exclusivo com unidade não é bloqueado', () => {
  assert.equal(localExclusivoSemUnidade('exclusivo', 'SAGA'), false);
});

test('local compartilhado nunca é bloqueado, mesmo sem unidade', () => {
  assert.equal(localExclusivoSemUnidade('compartilhado', ''), false);
});
