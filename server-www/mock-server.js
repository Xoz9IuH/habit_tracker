const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const api = require('./api-core.js');

const PORT = Number(process.env.PORT || 8080);
const SITE_DIR = path.resolve(
  process.env.SITE_DIR || path.join(__dirname, '..', 'build', 'web'),
);
const HAS_SITE = fs.existsSync(path.join(SITE_DIR, 'index.html'));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.map': 'application/json',
  '.txt': 'text/plain; charset=utf-8',
  '.bin': 'application/octet-stream',
};

function staticFile(pathname) {
  const clean = decodeURIComponent(pathname.split('?')[0]);
  const target = path.join(
    SITE_DIR,
    path.normalize(clean).replace(/^([/\\])+/, ''),
  );
  if (
    target.startsWith(SITE_DIR) &&
    fs.existsSync(target) &&
    fs.statSync(target).isFile()
  ) {
    const ext = path.extname(target).toLowerCase();
    return {
      body: fs.readFileSync(target),
      type: MIME[ext] || 'application/octet-stream',
      cache: ext === '.html' ? 'no-cache' : 'public, max-age=600',
    };
  }
  if (path.extname(clean) === '') {
    const index = path.join(SITE_DIR, 'index.html');
    if (fs.existsSync(index)) {
      return {
        body: fs.readFileSync(index),
        type: 'text/html; charset=utf-8',
        cache: 'no-cache',
      };
    }
  }
  return null;
}

(async () => {
  const apiServer = await api.start(PORT + 1);

  const site = http.createServer((req, res) => {
    const url = (req.url || '/').split('?')[0];
    if (url.startsWith('/api')) {
      const proxy = http.request(
        {
          hostname: '127.0.0.1',
          port: PORT + 1,
          path: req.url,
          method: req.method,
          headers: { ...req.headers, host: `localhost:${PORT + 1}` },
        },
        (upstream) => {
          res.writeHead(upstream.statusCode || 502, upstream.headers);
          upstream.pipe(res);
        },
      );
      proxy.on('error', () => {
        res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end('API недоступен');
      });
      req.pipe(proxy);
      return;
    }

    if (!HAS_SITE) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Сборка клиента не найдена: ' + SITE_DIR);
      return;
    }

    const file = staticFile(req.url || '/');
    if (!file) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Не найдено: ' + url);
      return;
    }
    res.writeHead(200, {
      'Content-Type': file.type,
      'Content-Length': file.body.length,
      'Cache-Control': file.cache,
    });
    res.end(req.method === 'HEAD' ? undefined : file.body);
  });

  site.listen(PORT, () => {
    console.log(`Страница: http://localhost:${PORT}/`);
    console.log(`API: http://localhost:${PORT}/api (${api.storage()})`);
    console.log(HAS_SITE ? `Клиент: ${SITE_DIR}` : 'Клиент не найден');
  });

  process.on('SIGTERM', () => process.exit(0));
  process.on('SIGINT', () => process.exit(0));
})();
