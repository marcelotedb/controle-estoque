// Verificação manual do login (Task 13), automatizada com Playwright (sem projeto
// Supabase real: injeta sessão/resultado via window.__FIXTURE_SESSAO__ e
// window.__CHAMAR_LOGIN_TESTE__).
import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import assert from 'node:assert/strict';

const WEB_DIR = new URL('..', import.meta.url).pathname;
const TIPOS = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css' };

const servidor = createServer(async (req, res) => {
  const caminho = join(WEB_DIR, req.url === '/' ? 'index.html' : req.url.slice(1));
  try {
    const conteudo = await readFile(caminho);
    res.writeHead(200, { 'Content-Type': TIPOS[extname(caminho)] || 'text/plain' });
    res.end(conteudo);
  } catch {
    res.writeHead(404);
    res.end('não encontrado');
  }
});

await new Promise((resolve) => servidor.listen(0, resolve));
const porta = servidor.address().port;

const browser = await chromium.launch();
try {
  // Cenário 1: sem sessão, o painel redireciona para o login preservando a página de volta.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(() => { window.__FIXTURE_SESSAO__ = null; });
    await pagina.goto(`http://localhost:${porta}/index.html`);
    await pagina.waitForURL(/login\.html\?redirect=index\.html/);
    assert.match(pagina.url(), /login\.html\?redirect=index\.html/);
  }
  console.log('Cenário 1/3 ok: sem sessão, index.html redireciona para login.html?redirect=index.html');

  // Cenário 2: com sessão, o painel carrega normalmente (sem redirecionar).
  {
    const pagina = await browser.newPage();
    const fixtureSaldos = [
      { codigo: 'A1', nome: 'Item', localizacao: null, saldo_disponivel: 5, saldo_em_uso: 0, saldo_pendente: 0, quantidade_minima: 1, em_alerta: false },
    ];
    await pagina.addInitScript((f) => {
      window.__FIXTURE_SESSAO__ = { user: { id: 'u1' } };
      window.__FIXTURE_SALDOS__ = f;
    }, fixtureSaldos);
    await pagina.goto(`http://localhost:${porta}/index.html`);
    await pagina.waitForSelector('.linha');
    assert.match(pagina.url(), /index\.html$/);
  }
  console.log('Cenário 2/3 ok: com sessão, index.html carrega sem redirecionar');

  // Cenário 3: credenciais inválidas mostram a mensagem em português, sem redirecionar.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(() => {
      window.__CHAMAR_LOGIN_TESTE__ = async () => ({ erro: { message: 'Invalid login credentials' } });
    });
    await pagina.goto(`http://localhost:${porta}/login.html`);
    await pagina.fill('#email', 'marcelo@example.com');
    await pagina.fill('#senha', 'senha-errada');
    await pagina.click('button[type=submit]');
    await pagina.waitForSelector('#mensagem:not([hidden])');
    const mensagem = await pagina.locator('#mensagem').textContent();
    assert.equal(mensagem, 'E-mail ou senha incorretos.');
    assert.match(pagina.url(), /login\.html$/);
  }
  console.log('Cenário 3/3 ok: credenciais inválidas mostram mensagem em português e não saem do login');

  console.log('Verificação de login: 3/3 cenários pass');
} finally {
  await browser.close();
  servidor.close();
}
