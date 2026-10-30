// Verificação manual da Task 9, automatizada com Playwright (sem projeto Supabase
// real: injeta fixtures de listagem e respostas de chamar() via window.__CHAMAR_TESTE__).
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

const itens = [{ id: 'item-1', codigo: 'A1', nome: 'Parafuso 6mm' }];
const unidades = [
  { id: 'xam-id', codigo: 'XAM', nome: 'Xambioá (sede)' },
  { id: 'saga-id', codigo: 'SAGA', nome: 'São Geraldo do Araguaia' },
];
const locais = [
  { id: 'loja-id', nome: 'Loja', tipo: 'compartilhado', unidade_id: null },
  { id: 'eldorado-id', nome: 'Eldorado', tipo: 'exclusivo', unidade_id: 'saga-id' },
];

const browser = await chromium.launch();
try {
  // Cenário 1: retirada além do saldo — a mensagem exata do banco é exibida, sem número gerado.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(
      (f) => {
        window.__FIXTURE_ITENS__ = f.itens;
        window.__FIXTURE_UNIDADES__ = f.unidades;
        window.__FIXTURE_LOCAIS__ = f.locais;
        window.__CHAMAR_TESTE__ = async () => ({ dados: null, erro: { message: 'saldo insuficiente: disponível 2' } });
      },
      { itens, unidades, locais }
    );
    await pagina.goto(`http://localhost:${porta}/retirada.html`);
    await pagina.fill('#item-busca', 'A1 — Parafuso 6mm');
    await pagina.fill('#quantidade', '10');
    await pagina.selectOption('#unidade', 'XAM');
    await pagina.fill('#local-busca', 'Loja');
    await pagina.fill('#responsavel', 'Lindomar');
    await pagina.click('button[type=submit]');
    await pagina.waitForSelector('#mensagem:not([hidden])');
    const texto = await pagina.locator('#mensagem').textContent();
    assert.equal(texto, 'saldo insuficiente: disponível 2');
    const resultadoOculto = await pagina.locator('#resultado').isHidden();
    assert.ok(resultadoOculto, 'esperado que nenhum número de retirada apareça');
    await pagina.close();
  }
  console.log('Cenário 1/4 ok: retirada além do saldo mostra a mensagem do banco');

  // Cenário 2: devolução além do saldo em uso.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(
      (f) => {
        window.__FIXTURE_LOCAIS__ = f.locais;
        window.__FIXTURE_RETIRADAS__ = [{ id: 'm1', numero: 'RET-0001', responsavel: 'Lindomar', data_hora: '2026-10-28T10:00:00Z', local_uso_id: 'loja-id' }];
        window.__CHAMAR_TESTE__ = async () => ({ dados: null, erro: { message: 'quantidade excede o saldo em uso (3)' } });
      },
      { locais }
    );
    await pagina.goto(`http://localhost:${porta}/devolucao.html`);
    await pagina.waitForSelector('.resultado-busca');
    await pagina.click('.resultado-busca');
    await pagina.fill('#quantidade', '5');
    await pagina.selectOption('#condicao', 'reuso');
    await pagina.fill('#responsavel', 'Lindomar');
    await pagina.click('button[type=submit]');
    await pagina.waitForSelector('#mensagem:not([hidden])');
    const texto = await pagina.locator('#mensagem').textContent();
    assert.equal(texto, 'quantidade excede o saldo em uso (3)');
    await pagina.close();
  }
  console.log('Cenário 2/4 ok: devolução além do saldo em uso mostra a mensagem do banco');

  // Cenário 3: devolução de retirada já devolvida.
  {
    const pagina = await browser.newPage();
    await pagina.addInitScript(
      (f) => {
        window.__FIXTURE_LOCAIS__ = f.locais;
        window.__FIXTURE_RETIRADAS__ = [{ id: 'm1', numero: 'RET-0001', responsavel: 'Lindomar', data_hora: '2026-10-28T10:00:00Z', local_uso_id: 'loja-id' }];
        window.__CHAMAR_TESTE__ = async () => ({ dados: null, erro: { message: 'retirada RET-0001 já devolvida' } });
      },
      { locais }
    );
    await pagina.goto(`http://localhost:${porta}/devolucao.html`);
    await pagina.waitForSelector('.resultado-busca');
    await pagina.click('.resultado-busca');
    await pagina.fill('#quantidade', '1');
    await pagina.selectOption('#condicao', 'reuso');
    await pagina.fill('#responsavel', 'Lindomar');
    await pagina.click('button[type=submit]');
    await pagina.waitForSelector('#mensagem:not([hidden])');
    const texto = await pagina.locator('#mensagem').textContent();
    assert.equal(texto, 'retirada RET-0001 já devolvida');
    await pagina.close();
  }
  console.log('Cenário 3/4 ok: devolução de retirada já devolvida mostra a mensagem do banco');

  // Cenário 4: retirada de local exclusivo de outra unidade exige confirmação antes de registrar.
  {
    const pagina = await browser.newPage();
    let chamadas = 0;
    await pagina.addInitScript(
      (f) => {
        window.__FIXTURE_ITENS__ = f.itens;
        window.__FIXTURE_UNIDADES__ = f.unidades;
        window.__FIXTURE_LOCAIS__ = f.locais;
        window.__CHAMADAS_RETIRADA__ = [];
        window.__CHAMAR_TESTE__ = async (funcao, params) => {
          window.__CHAMADAS_RETIRADA__.push(params);
          if (!params.p_confirmar_unidade_diferente) {
            return { dados: null, erro: { message: 'confirmação necessária: local pertence a outra unidade' } };
          }
          return { dados: [{ numero: 'RET-0099', aviso: 'local de uso Eldorado pertence a outra unidade' }], erro: null };
        };
      },
      { itens, unidades, locais }
    );
    await pagina.goto(`http://localhost:${porta}/retirada.html`);
    await pagina.fill('#item-busca', 'A1 — Parafuso 6mm');
    await pagina.fill('#quantidade', '2');
    await pagina.selectOption('#unidade', 'XAM');
    await pagina.fill('#local-busca', 'Eldorado');
    await pagina.fill('#responsavel', 'Lindomar');
    await pagina.click('button[type=submit]');

    await pagina.waitForSelector('#dialogo-confirmacao:not([hidden])');
    const resultadoAindaOculto = await pagina.locator('#resultado').isHidden();
    assert.ok(resultadoAindaOculto, 'esperado que o diálogo apareça antes de registrar');

    chamadas = await pagina.evaluate(() => window.__CHAMADAS_RETIRADA__.length);
    assert.equal(chamadas, 0, 'esperado que o diálogo apareça sem chamar o banco, pela checagem no cliente');

    await pagina.click('#btn-confirmar-unidade');
    await pagina.waitForSelector('#resultado:not([hidden])');
    const texto = await pagina.locator('#resultado').textContent();
    assert.equal(texto, 'RET-0099 — local de uso Eldorado pertence a outra unidade');

    chamadas = await pagina.evaluate(() => window.__CHAMADAS_RETIRADA__.length);
    assert.equal(chamadas, 1, 'esperado uma única chamada ao banco, já confirmada');
    await pagina.close();
  }
  console.log('Cenário 4/4 ok: retirada de local exclusivo de outra unidade exige confirmação');

  console.log('Verificação de retirada e devolução: 4/4 cenários pass');
} finally {
  await browser.close();
  servidor.close();
}
