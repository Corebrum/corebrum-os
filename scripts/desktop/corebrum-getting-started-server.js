#!/usr/bin/env node
'use strict';

// Loopback static server for the Getting Started pages.
// Uses Node's http and fs modules. No npm packages.

const http = require('http');
const fs = require('fs');
const path = require('path');

const HOST = '127.0.0.1';
const PORT = Number(process.env.COREBRUM_GETTING_STARTED_PORT || 8765);
const ROOT = process.env.COREBRUM_GETTING_STARTED_ROOT || '/usr/share/corebrum';
const NAV_MARKER = '<!-- corebrum-nav -->';

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
};

function fail(message) {
  process.stderr.write(`corebrum-getting-started: ${message}\n`);
  process.exit(1);
}

if (!Number.isInteger(PORT) || PORT < 0 || PORT > 65535) {
  fail('invalid port');
}

let ROOT_REAL;
try {
  ROOT_REAL = fs.realpathSync(ROOT);
} catch (_err) {
  fail(`missing ${ROOT}`);
}

function resolveRequest(urlPath) {
  let reqPath;
  try {
    reqPath = decodeURIComponent(urlPath.split('?')[0]);
  } catch (_err) {
    return null;
  }
  if (reqPath.includes('\0')) {
    return null;
  }
  if (reqPath === '/getting-started' || reqPath === '/getting-started/') {
    reqPath = '/getting-started/index.html';
  }
  const normalized = path.posix.normalize(reqPath);
  const rel = normalized.replace(/^\/+/, '');
  if (!rel || rel === '.' || rel.startsWith('..') || rel.includes('\0')) {
    return null;
  }
  const full = path.resolve(ROOT, rel);
  const rootResolved = path.resolve(ROOT);
  if (full !== rootResolved && !full.startsWith(rootResolved + path.sep)) {
    return null;
  }
  return full;
}

function insideRoot(realPath) {
  return realPath === ROOT_REAL || realPath.startsWith(ROOT_REAL + path.sep);
}

function pageName(filePath) {
  let docs;
  try {
    docs = fs.realpathSync(path.join(ROOT_REAL, 'getting-started'));
  } catch (_err) {
    return '';
  }
  if (path.dirname(filePath) !== docs) {
    return '';
  }
  return path.basename(filePath);
}

function withNav(html, name) {
  const navPath = path.join(ROOT, 'getting-started', 'nav.html');
  const nav = fs.readFileSync(navPath, 'utf8');
  const marked = nav.replace(
    `<a href="${name}">`,
    `<a href="${name}" aria-current="page">`
  );
  return html.replace(NAV_MARKER, marked);
}

function send(res, status, type, body) {
  res.writeHead(status, {
    'Content-Type': type,
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-cache',
    'X-Content-Type-Options': 'nosniff',
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    send(res, 405, 'text/plain; charset=utf-8', 'Method not allowed\n');
    return;
  }
  const full = resolveRequest(req.url || '/');
  if (!full) {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  let real;
  let stat;
  try {
    real = fs.realpathSync(full);
    stat = fs.statSync(real);
  } catch (_err) {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  if (!insideRoot(real) || !stat.isFile()) {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  const ext = path.extname(real).toLowerCase();
  const type = TYPES[ext];
  if (!type) {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  let body;
  try {
    body = fs.readFileSync(real);
  } catch (_err) {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  const name = pageName(real);
  if (name === 'nav.html') {
    send(res, 404, 'text/plain; charset=utf-8', 'Not found\n');
    return;
  }
  if (name && ext === '.html') {
    const html = body.toString('utf8');
    if (html.includes(NAV_MARKER)) {
      try {
        body = Buffer.from(withNav(html, name), 'utf8');
      } catch (_err) {
        send(res, 500, 'text/plain; charset=utf-8', 'Sidebar missing\n');
        return;
      }
    }
  }
  if (req.method === 'HEAD') {
    res.writeHead(200, {
      'Content-Type': type,
      'Content-Length': body.length,
      'Cache-Control': 'no-cache',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end();
    return;
  }
  send(res, 200, type, body);
});

server.listen(PORT, HOST, () => {
  const bound = server.address();
  process.stdout.write(`corebrum-getting-started: http://${HOST}:${bound.port}/getting-started/\n`);
});
