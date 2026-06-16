import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer as createHttpServer } from "node:http";
import { extname, join, normalize, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml; charset=utf-8"
};

export function createStaticServer(root = __dirname) {
  const base = resolve(root);
  return createHttpServer((request, response) => {
    const url = new URL(request.url || "/", "http://localhost");
    const requested = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
    const filePath = resolve(join(base, normalize(requested)));

    if (!filePath.startsWith(base) || !existsSync(filePath) || !statSync(filePath).isFile()) {
      response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
      response.end("Not found");
      return;
    }

    response.writeHead(200, {
      "content-type": MIME[extname(filePath)] || "application/octet-stream",
      "cache-control": "no-store"
    });
    createReadStream(filePath).pipe(response);
  });
}

export function startServer({ host = "127.0.0.1", port = Number(process.env.PORT || 5173), root = __dirname } = {}) {
  const server = createStaticServer(root);
  const tryListen = (candidate) => {
    server.once("error", (error) => {
      if (error.code === "EADDRINUSE" && candidate < port + 20) {
        tryListen(candidate + 1);
      } else {
        throw error;
      }
    });
    server.listen(candidate, host, () => {
      const address = server.address();
      console.log(`绯线远征已启动: http://${host}:${address.port}/`);
    });
  };
  tryListen(port);
  return server;
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  startServer();
}
