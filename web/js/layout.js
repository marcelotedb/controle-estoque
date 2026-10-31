// Comportamento puramente visual do layout (abrir/fechar o menu no celular).
// Não participa de nenhuma regra de negócio — só mostra/esconde a barra lateral.
(function () {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('overlay');
  const botaoMenu = document.getElementById('btn-menu');
  if (!sidebar || !overlay || !botaoMenu) return;

  function abrir() {
    sidebar.classList.add('aberta');
    overlay.classList.add('visivel');
  }

  function fechar() {
    sidebar.classList.remove('aberta');
    overlay.classList.remove('visivel');
  }

  botaoMenu.addEventListener('click', abrir);
  overlay.addEventListener('click', fechar);
  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape') fechar();
  });
})();
