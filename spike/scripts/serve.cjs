const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.cact': 'application/octet-stream', '.wav': 'audio/wav', '.png': 'image/png', '.woff2': 'font/woff2' };
function makeServer(directory = root) {
  const servedRoot = path.resolve(directory);
  return http.createServer((req, res) => {
    let target;
    try { target = path.resolve(servedRoot, '.' + decodeURIComponent(new URL(req.url, 'http://localhost').pathname)); }
    catch { res.writeHead(400).end(); return; }
    if (target !== servedRoot && !target.startsWith(servedRoot + path.sep)) { res.writeHead(403).end(); return; }
    if (target === servedRoot) target = path.join(servedRoot, 'index.html');
    fs.stat(target, (error, stat) => {
      if (error || !stat.isFile()) { res.writeHead(404).end('Not found'); return; }
      res.writeHead(200, { 'Content-Type': mime[path.extname(target)] || 'application/octet-stream', 'Content-Length': stat.size });
      fs.createReadStream(target).pipe(res);
    });
  });
}
if (require.main === module) makeServer().listen(4173, '127.0.0.1', () => console.log('Triage spike: http://localhost:4173'));
module.exports = { makeServer };
