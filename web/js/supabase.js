// Cliente Supabase e helper de chamada (Task 8).
//
// ATENÇÃO: estas constantes são trocadas na Task 12, quando o projeto Supabase
// real for criado. A chave aqui é a chave publicável (anon key): ela é feita para
// ficar no navegador — a segurança do sistema depende das políticas de RLS do
// banco (Task 6), nunca de esconder esta chave.
const SUPABASE_URL = 'https://SEU-PROJETO.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'SUBSTITUA-PELA-CHAVE-PUBLICAVEL';

export const cliente = (typeof window !== 'undefined' && window.supabase)
  ? window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY)
  : null;

/**
 * Chama uma função do banco (RPC) e devolve sempre {dados, erro}, nunca lança.
 * Mantém a tela simples: cada chamada decide o que mostrar a partir desses dois campos.
 */
export async function chamar(funcao, params = {}) {
  if (!cliente) {
    return { dados: null, erro: { message: 'cliente Supabase não configurado' } };
  }
  const { data, error } = await cliente.rpc(funcao, params);
  return { dados: data, erro: error };
}

/**
 * Consultas simples de listagem (Task 9), usadas para preencher os campos das
 * telas de retirada e devolução. Sempre devolvem {dados, erro}, como `chamar`.
 */
async function listar(tabela, colunas, filtros = {}) {
  if (!cliente) {
    return { dados: null, erro: { message: 'cliente Supabase não configurado' } };
  }
  let consulta = cliente.from(tabela).select(colunas);
  for (const [coluna, valor] of Object.entries(filtros)) {
    consulta = consulta.eq(coluna, valor);
  }
  const { data, error } = await consulta;
  return { dados: data, erro: error };
}

export const listarItens = () => listar('itens', 'id, codigo, nome');
export const listarLocais = () => listar('locais_uso', 'id, nome, tipo, unidade_id');
export const listarUnidades = () => listar('unidades', 'id, codigo, nome');
export const listarRetiradasConcluidas = () =>
  listar('movimentacoes', 'id, numero, responsavel, data_hora, local_uso_id', { tipo: 'retirada', status: 'concluida' });
