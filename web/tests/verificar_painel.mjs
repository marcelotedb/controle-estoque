// Verificação manual da Task 8, automatizada com Playwright (sem projeto Supabase
// real: injeta a fixture antes de carregar a página, pelo hook window.__FIXTURE_SALDOS__).
// A conectividade real com o backend só é verificada na Task 12, quando o projeto existir.
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

const fixture = [
  { codigo: 'A1', nome: 'Parafuso 6mm', localizacao: 'prateleira 1', saldo_disponivel: 2, saldo_em_uso: 0, saldo_pendente: 0, quantidade_minima: 5, em_alerta: true },
  { codigo: 'A2', nome: 'Conector Azul', localizacao: 'prateleira 2', saldo_disponivel: 10, saldo_em_uso: 0, saldo_pendente: 3, quantidade_minima: 2, em_alerta: false },
  { codigo: 'A3', nome: 'Cabo de rede', localizacao: 'prateleira 3', saldo_disponivel: 20, saldo_em_uso: 0, saldo_pendente: 0, quantidade_minima: 1, em_alerta: false },
];

const browser = await chromium.launch();
try {
  // 1. Celular (375px de largura): sem rolagem horizontal, alerta no topo.
  const paginaCelular = await browser.newPage({ viewport: { width: 375, height: 700 } });
  await paginaCelular.addInitScript((f) => { window.__FIXTURE_SALDOS__ = f; }, fixture);
  await paginaCelular.goto(`http://localhost:${porta}/index.html`);
  await paginaCelular.waitForSelector('.linha');

  const larguraDocumento = await paginaCelular.evaluate(() => document.documentElement.scrollWidth);
  const larguraJanela = await paginaCelular.evaluate(() => window.innerWidth);
  assert.ok(larguraDocumento <= larguraJanela, `esperado sem rolagem horizontal, documento ${larguraDocumento}px > janela ${larguraJanela}px`);

  const primeiraLinha = await paginaCelular.locator('.linha').first().getAttribute('data-codigo');
  assert.equal(primeiraLinha, 'A1', 'esperado que o item em alerta (A1) apareça primeiro');

  const temClasseAlerta = await paginaCelular.locator('.linha').first().evaluate((el) => el.classList.contains('linha-alerta'));
  assert.ok(temClasseAlerta, 'esperado destaque visual (classe linha-alerta) no item em alerta');

  await paginaCelular.screenshot({ path: '/tmp/claude-0/-home-claude/5409e995-86c4-5bfd-92ca-953863c2d564/scratchpad/painel-celular.png' });
  await paginaCelular.close();

  // 2. Busca filtra para um só item.
  const paginaBusca = await browser.newPage({ viewport: { width: 1024, height: 800 } });
  await paginaBusca.addInitScript((f) => { window.__FIXTURE_SALDOS__ = f; }, fixture);
  await paginaBusca.goto(`http://localhost:${porta}/index.html`);
  await paginaBusca.waitForSelector('.linha');
  await paginaBusca.fill('#busca', 'conector');
  await paginaBusca.waitForTimeout(100);
  const linhasVisiveisAposBusca = await paginaBusca.locator('.linha').count();
  assert.equal(linhasVisiveisAposBusca, 1, `esperado 1 linha após buscar "conector", obtido ${linhasVisiveisAposBusca}`);
  const codigoAposBusca = await paginaBusca.locator('.linha').first().getAttribute('data-codigo');
  assert.equal(codigoAposBusca, 'A2');
  await paginaBusca.close();

  console.log('Verificação do painel: 4/4 checks pass (ordem, sem rolagem horizontal, destaque de alerta, busca)');
} finally {
  await browser.close();
  servidor.close();
}
