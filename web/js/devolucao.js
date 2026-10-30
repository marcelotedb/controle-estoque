// Lógica pura da tela de devolução (Task 9): busca de retirada por número,
// responsável, local ou data.
import { normalizar } from './texto.js';

/** Filtra retiradas por número, responsável, nome do local ou data (AAAA-MM-DD). */
export function filtrarRetiradas(retiradas, termo) {
  const alvo = normalizar(termo || '').trim();
  if (!alvo) return retiradas;
  return retiradas.filter((r) => {
    const data = (r.data_hora || '').slice(0, 10);
    return (
      normalizar(r.numero).includes(alvo) ||
      normalizar(r.responsavel).includes(alvo) ||
      normalizar(r.local_nome || '').includes(alvo) ||
      data.includes(alvo)
    );
  });
}
