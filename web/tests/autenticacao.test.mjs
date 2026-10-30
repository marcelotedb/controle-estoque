// Testes da lógica pura de login (Task 13): ler o destino de redirecionamento e
// traduzir erros do Supabase Auth, sem precisar de rede ou de uma sessão real.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { destinoRedirecionamento, urlDeLogin, mensagemErroLogin } from '../js/autenticacao.js';

test('destinoRedirecionamento lê a página pedida na URL', () => {
  assert.equal(destinoRedirecionamento('?redirect=retirada.html'), 'retirada.html');
});

test('destinoRedirecionamento usa index.html quando não há parâmetro', () => {
  assert.equal(destinoRedirecionamento(''), 'index.html');
});

test('destinoRedirecionamento rejeita um domínio externo (redirecionamento aberto)', () => {
  assert.equal(destinoRedirecionamento('?redirect=https://site-malicioso.com'), 'index.html');
});

test('destinoRedirecionamento rejeita um caminho com barra', () => {
  assert.equal(destinoRedirecionamento('?redirect=../index.html'), 'index.html');
});

test('urlDeLogin preserva a página atual como destino de retorno', () => {
  assert.equal(urlDeLogin('retirada.html'), 'login.html?redirect=retirada.html');
});

test('mensagemErroLogin traduz credenciais inválidas', () => {
  assert.equal(mensagemErroLogin({ message: 'Invalid login credentials' }), 'E-mail ou senha incorretos.');
});

test('mensagemErroLogin traduz e-mail não confirmado', () => {
  assert.equal(
    mensagemErroLogin({ message: 'Email not confirmed' }),
    'E-mail ainda não confirmado. Verifique sua caixa de entrada.'
  );
});

test('mensagemErroLogin traduz excesso de tentativas', () => {
  assert.equal(mensagemErroLogin({ message: 'Too many requests' }), 'Muitas tentativas. Aguarde um pouco e tente de novo.');
});

test('mensagemErroLogin cai para a mensagem original em erros desconhecidos', () => {
  assert.equal(mensagemErroLogin({ message: 'network error' }), 'Não foi possível entrar: network error');
});

test('mensagemErroLogin devolve null quando não há erro', () => {
  assert.equal(mensagemErroLogin(null), null);
});
