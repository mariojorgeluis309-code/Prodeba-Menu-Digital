import fs from 'node:fs';
import vm from 'node:vm';

const html = fs.readFileSync('index.html', 'utf8');
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)];
if (!scripts.length) throw new Error('Nenhum bloco script encontrado.');

let checked = 0;
for (let i = 0; i < scripts.length; i++) {
  const attrs = scripts[i][1] || '';
  const source = scripts[i][2] || '';
  if (/\bsrc\s*=/.test(attrs) || !source.trim()) continue;
  new vm.Script(source, { filename: 'index.html:inline-script-' + (i + 1) });
  checked++;
}

const required = [
  'criar_pedido_transacional',
  'rastrear_pedido',
  'resolver_qr',
  'confirmar_pagamento_pedido',
  'renderPaymentMethods',
  'createGeneralQr',
  "storage.from('produtos').upload"
];
for (const token of required) {
  if (!html.includes(token)) throw new Error('Funcionalidade essencial ausente: ' + token);
}

console.log('Prodeba: ' + checked + ' blocos JavaScript validados; verificações essenciais aprovadas.');
