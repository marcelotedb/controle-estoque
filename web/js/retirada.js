// Lógica pura da tela de retirada (Task 9): busca de item e local, e a regra de
// confirmação de unidade (espelha a regra do banco em db/03_operacoes.sql, para
// mostrar o diálogo antes de chamar registrar_retirada; o banco continua sendo
// a autoridade final).
import { normalizar } from './texto.js';

/** Filtra itens por nome ou código. */
export function filtrarItens(itens, termo) {
  const alvo = normalizar(termo || '').trim();
  if (!alvo) return itens;
  return itens.filter((i) => normalizar(i.nome).includes(alvo) || normalizar(i.codigo).includes(alvo));
}

/** Filtra locais de uso por nome. */
export function filtrarLocais(locais, termo) {
  const alvo = normalizar(termo || '').trim();
  if (!alvo) return locais;
  return locais.filter((l) => normalizar(l.nome).includes(alvo));
}

/**
 * Um local exclusivo de outra unidade exige confirmação antes de registrar a
 * retirada. Compartilhado nunca exige; exclusivo da própria unidade não exige.
 */
export function localExigeConfirmacao(local, unidadeId) {
  return local.tipo === 'exclusivo' && local.unidade_id !== unidadeId;
}

/** Reconhece a mensagem de confirmação de unidade devolvida pelo banco (Task 3). */
export function precisaConfirmarUnidade(mensagemErro) {
  return (mensagemErro || '').includes('confirmação necessária');
}
