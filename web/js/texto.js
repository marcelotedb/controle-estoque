// Normalização de texto para busca, compartilhada entre painel, retirada e devolução.
// Remove acentos e diferença de maiúsculas, para que "Eldorado" e "El Dorado" combinem na busca.

/** Normaliza texto para comparação: minúsculas e sem acentos. */
export function normalizar(texto) {
  return texto
    .toString()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}
