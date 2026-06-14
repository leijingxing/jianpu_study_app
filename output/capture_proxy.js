const http = require('http');
const https = require('https');
const net = require('net');
const { URL } = require('url');

const port = Number(process.env.CAPTURE_PROXY_PORT || 8888);
const maxBody = 20000;

function now() {
  return new Date().toISOString();
}

function cleanHeaders(headers) {
  const copy = { ...headers };
  for (const key of Object.keys(copy)) {
    if (/authorization|cookie|token|password/i.test(key)) {
      copy[key] = '[redacted]';
    }
  }
  return copy;
}

function clip(value) {
  if (!value) return '';
  const text = Buffer.isBuffer(value) ? value.toString('utf8') : String(value);
  return text.length > maxBody ? text.slice(0, maxBody) + `\n...[truncated ${text.length - maxBody} chars]` : text;
}

function logBlock(title, data) {
  console.log(`\n===== ${title} ${now()} =====`);
  console.log(JSON.stringify(data, null, 2));
}

const server = http.createServer((clientReq, clientRes) => {
  const chunks = [];
  clientReq.on('data', (chunk) => chunks.push(chunk));
  clientReq.on('end', () => {
    const requestBody = Buffer.concat(chunks);
    let target;
    try {
      target = new URL(clientReq.url);
    } catch {
      const host = clientReq.headers.host;
      target = new URL(`http://${host}${clientReq.url}`);
    }

    logBlock('REQUEST', {
      method: clientReq.method,
      url: target.toString(),
      headers: cleanHeaders(clientReq.headers),
      body: clip(requestBody),
    });

    const isHttps = target.protocol === 'https:';
    const transport = isHttps ? https : http;
    const headers = { ...clientReq.headers, host: target.host };
    delete headers['proxy-connection'];

    const upstream = transport.request({
      protocol: target.protocol,
      hostname: target.hostname,
      port: target.port || (isHttps ? 443 : 80),
      method: clientReq.method,
      path: `${target.pathname}${target.search}`,
      headers,
    }, (upstreamRes) => {
      const responseChunks = [];
      upstreamRes.on('data', (chunk) => {
        responseChunks.push(chunk);
        clientRes.write(chunk);
      });
      upstreamRes.on('end', () => {
        clientRes.end();
        logBlock('RESPONSE', {
          url: target.toString(),
          statusCode: upstreamRes.statusCode,
          headers: cleanHeaders(upstreamRes.headers),
          body: clip(Buffer.concat(responseChunks)),
        });
      });
      clientRes.writeHead(upstreamRes.statusCode || 502, upstreamRes.headers);
    });

    upstream.on('error', (error) => {
      logBlock('UPSTREAM_ERROR', { url: target.toString(), message: error.message });
      clientRes.writeHead(502, { 'content-type': 'text/plain' });
      clientRes.end(error.message);
    });

    if (requestBody.length) upstream.write(requestBody);
    upstream.end();
  });
});

server.on('connect', (req, clientSocket, head) => {
  logBlock('CONNECT', { host: req.url, headers: cleanHeaders(req.headers) });
  const [host, portText] = req.url.split(':');
  const upstream = net.connect(Number(portText || 443), host, () => {
    clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
    if (head.length) upstream.write(head);
    upstream.pipe(clientSocket);
    clientSocket.pipe(upstream);
  });
  upstream.on('error', (error) => {
    logBlock('CONNECT_ERROR', { host: req.url, message: error.message });
    clientSocket.end();
  });
});

server.listen(port, '127.0.0.1', () => {
  console.log(`capture proxy listening on 127.0.0.1:${port}`);
});
