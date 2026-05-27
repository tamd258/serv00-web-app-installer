const http = require('http');
const port = Number(process.env.PORT || 3000);
http.createServer((req, res) => res.end('Hello from Node.js')).listen(port, '127.0.0.1');
