// Lógica pura do painel (Task 8): separa alertas e pendências, e filtra por busca.
// Sem dependência de rede, para poder ser testada sem um projeto Supabase real.
import { normalizar } from './texto.js';

/**
 * Separa as linhas de saldos_itens em três seções, nesta ordem de exibição:
 *   alertas  — saldo disponível <= quantidade mínima (em_alerta = true)
 *   pendentes — não está em alerta, mas tem saldo_pendente > 0
 *   normais  — o resto
 * Um item em alerta nunca aparece também em pendentes, mesmo com saldo_pendente > 0.
 */
export function separarSecoes(linhas) {
  const alertas = [];
  const pendentes = [];
  const normais = [];
  for (const linha of linhas) {
    if (linha.em_alerta) {
      alertas.push(linha);
    } else if (linha.saldo_pendente > 0) {
      pendentes.push(linha);
    } else {
      normais.push(linha);
    }
  }
  return { alertas, pendentes, normais };
}

/** Filtra linhas por nome, código ou localização, sem diferenciar maiúsculas ou acentos. */
export function filtrarLinhas(linhas, termo) {
  const alvo = normalizar(termo || '').trim();
  if (!alvo) return linhas;
  return linhas.filter((linha) =>
    normalizar(linha.nome).includes(alvo) ||
    normalizar(linha.codigo).includes(alvo) ||
    normalizar(linha.localizacao || '').includes(alvo)
  );
}
