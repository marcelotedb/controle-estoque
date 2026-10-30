// Lógica pura do cadastro de itens e locais (Task 10).

/** Um local exclusivo sem unidade é bloqueado no cliente, antes de chegar ao banco. */
export function localExclusivoSemUnidade(tipo, unidadeCodigo) {
  return tipo === 'exclusivo' && !unidadeCodigo;
}
