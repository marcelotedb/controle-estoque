// Verificação manual da Task 10, automatizada com Playwright (sem projeto Supabase
// real: injeta respostas via window.__CHAMAR_TESTE__).
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
  // Cenário 1: cadastrar "Parafuso 6mm" e depois "PARAFUSO 6 MM" deve mostrar o
  // primeiro como parecido e exigir confirmação explícita antes de salvar.
  {
    const pagina = await browser.newPage();
    const chamadas = [];
    await pagina.addInitScript(() => {
      window.__CHAMADAS__ = [];
      window.__CHAMAR_TESTE__ = async (funcao, params) => {
        window.__CHAMADAS__.push({ funcao, params });
        if (funcao === 'verificar_duplicata_item') {
          return { dados: [{ item_id: '1', nome: 'Parafuso 6mm', codigo: 'ITM-0001' }], erro: null };
        }
        if (funcao === 'registrar_item') {
          return { dados: 'ITM-0002', erro: null };
        }
        return { dados: null, erro: { message: 'função não esperada no teste: ' + funcao } };
      };
    });
    await pagina.goto(`http://localhost:${porta}/itens.html`);
    await pagina.fill('#item-nome', 'PARAFUSO 6 MM');
    await pagina.selectOption('#item-categoria', 'Peças');
    await pagina.click('#form-item button[type=submit]');

    await pagina.waitForSelector('#item-parecidos:not([hidden])');
    const textoParecido = await pagina.locator('#item-lista-parecidos').textContent();
    assert.ok(textoParecido.includes('Parafuso 6mm'), 'esperado que o item parecido apareça antes de salvar');

    const resultadoAindaOculto = await pagina.locator('#item-resultado').isHidden();
    assert.ok(resultadoAindaOculto, 'esperado que nada seja salvo antes da confirmação explícita');

    await pagina.click('#item-btn-confirmar');
    await pagina.waitForSelector('#item-resultado:not([hidden])');
    const resultado = await pagina.locator('#item-resultado').textContent();
    assert.equal(resultado, 'Item cadastrado: ITM-0002');

    const nomesChamados = await pagina.evaluate(() => window.__CHAMADAS__.map((c) => c.funcao));
    assert.deepEqual(nomesChamados, ['verificar_duplicata_item', 'registrar_item']);
    await pagina.close();
  }
  console.log('Cenário 1/2 ok: item parecido exige confirmação explícita antes de salvar');

  // Cenário 2: local exclusivo sem unidade é bloqueado no cliente, sem chamar o banco.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(() => {
      window.__CHAMADAS__ = [];
      window.__CHAMAR_TESTE__ = async (funcao, params) => {
        window.__CHAMADAS__.push({ funcao, params });
        return { dados: null, erro: { message: 'não deveria ter sido chamado: ' + funcao } };
      };
    });
    await pagina.goto(`http://localhost:${porta}/itens.html`);
    await pagina.fill('#local-nome', 'Depósito sem unidade');
    await pagina.selectOption('#local-tipo', 'exclusivo');
    // Não seleciona a unidade de propósito.
    await pagina.click('#form-local button[type=submit]');

    await pagina.waitForSelector('#local-mensagem:not([hidden])');
    const mensagem = await pagina.locator('#local-mensagem').textContent();
    assert.match(mensagem, /unidade/i);

    const chamadas = await pagina.evaluate(() => window.__CHAMADAS__.length);
    assert.equal(chamadas, 0, 'esperado que o banco nunca seja chamado quando falta a unidade');
    await pagina.close();
  }
  console.log('Cenário 2/2 ok: local exclusivo sem unidade é bloqueado antes de chegar ao banco');

  console.log('Verificação de itens e locais: 2/2 cenários pass');
} finally {
  await browser.close();
  servidor.close();
}
