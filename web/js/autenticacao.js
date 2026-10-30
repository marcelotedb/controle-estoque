// Login simples por usuário (especificação, seção 6 "Acesso"). Contas são criadas
// pelo dono direto no painel do Supabase (Authentication → Users) — ver README.md —
// e só passam a enxergar algo depois de receber uma linha em `perfis` (Task 6).
// Este módulo reúne a parte testável sem rede: ler o destino de redirecionamento
// da URL e traduzir os erros do Supabase Auth para mensagens em português.

/**
 * Lê o parâmetro ?redirect= da URL de login e devolve a página para onde voltar
 * depois de autenticar. Só aceita um nome de página .html local (sem barra, sem
 * domínio), para nunca redirecionar para um site externo.
 */
export function destinoRedirecionamento(buscaDaUrl) {
  const params = new URLSearchParams(buscaDaUrl || '');
  const destino = params.get('redirect');
  if (!destino || !/^[a-zA-Z0-9_-]+\.html$/.test(destino)) {
    return 'index.html';
  }
  return destino;
}

/** Monta a URL de login preservando a página atual como destino de retorno. */
export function urlDeLogin(paginaAtual) {
  return 'login.html?redirect=' + encodeURIComponent(paginaAtual);
}

/** Traduz os erros mais comuns do Supabase Auth para mensagens em português. */
export function mensagemErroLogin(erro) {
  if (!erro) return null;
  const msg = (erro.message || '').toLowerCase();
  if (msg.includes('invalid login credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (msg.includes('email not confirmed')) {
    return 'E-mail ainda não confirmado. Verifique sua caixa de entrada.';
  }
  if (msg.includes('too many requests')) {
    return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
  }
  return 'Não foi possível entrar: ' + (erro.message || 'erro desconhecido');
}

/**
 * Garante que existe uma sessão autenticada antes de carregar uma página protegida
 * (painel, retirada, devolução, itens). Sem isso, as chamadas ao banco falhariam de
 * qualquer forma (tem_perfil() exige auth.uid()), mas aqui o aviso é imediato e em
 * português, redirecionando para o login com a página atual como destino de volta.
 */
export async function exigirSessao(cliente, paginaAtual) {
  let sessao;
  // Hook de teste: a verificação injeta uma sessão (ou null) aqui, sem precisar de
  // um projeto Supabase real. O redirecionamento abaixo roda igual nos dois casos,
  // para o teste também confirmar que a página de fato não é exibida sem sessão.
  if (Object.prototype.hasOwnProperty.call(window, '__FIXTURE_SESSAO__')) {
    sessao = window.__FIXTURE_SESSAO__;
  } else if (!cliente) {
    sessao = null;
  } else {
    const { data } = await cliente.auth.getSession();
    sessao = data && data.session ? data.session : null;
  }
  if (!sessao) {
    window.location.href = urlDeLogin(paginaAtual);
    return null;
  }
  return sessao;
}

/** Encerra a sessão e volta para o login. */
export async function sair(cliente) {
  if (cliente) await cliente.auth.signOut();
  window.location.href = 'login.html';
}
