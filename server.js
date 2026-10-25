import { open, realpath } from "node:fs/promises";
import { createServer as createHttpServer } from "node:http";
import { extname, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const MIME = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".otf": "font/otf", ".ttf": "font/ttf", ".woff2": "font/woff2",
  ".json": "application/json; charset=utf-8", ".svg": "image/svg+xml; charset=utf-8",
  ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
  ".webp": "image/webp", ".ogg": "audio/ogg", ".wav": "audio/wav",
  ".mp4": "video/mp4", ".wasm": "application/wasm", ".pck": "application/octet-stream"
};

function contained(base, target) {
  const path = relative(base, target);
  return path !== ".." && !path.startsWith(`..${sep}`) && !path.startsWith(sep);
}

function byteRange(header, size) {
  const match = /^bytes=(\d*)-(\d*)$/.exec(header);
  if (!match || (!match[1] && !match[2]) || size === 0) return null;
  const start = match[1] ? Number(match[1]) : Math.max(0, size - Number(match[2]));
  let end = match[1] && match[2] ? Number(match[2]) : size - 1;
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || start >= size || (!match[1] && Number(match[2]) === 0)) return null;
  end = Math.min(end, size - 1);
  return { start, end };
}

export function createStaticServer(root = __dirname) {
  // Canonical paths prevent sibling-prefix and symlink escapes.
  const basePromise = realpath(resolve(root));
  basePromise.catch(() => {});
  return createHttpServer(async (request, response) => {
    let file;
    const reply = (status, message, headers = {}) => {
      response.writeHead(status, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store", ...headers });
      response.end(request.method === "HEAD" ? undefined : message);
    };
    try {
      if (!["GET", "HEAD"].includes(request.method)) return reply(405, "Method not allowed", { allow: "GET, HEAD" });
      let requested;
      try { requested = decodeURIComponent(new URL(request.url || "/", "http://localhost").pathname); }
      catch { return reply(400, "Bad request"); }
      if (requested.includes("\0") || requested.includes("\\")) return reply(400, "Bad request");
      if (requested.split("/").some(part => part.startsWith("."))) return reply(404, "Not found");
      const base = await basePromise;
      const target = await realpath(resolve(base, `.${requested === "/" ? "/index.html" : requested}`));
      if (!contained(base, target)) return reply(404, "Not found");
      file = await open(target, "r");
      const stat = await file.stat();
      if (!stat.isFile()) return reply(404, "Not found");
      const etag = `W/"${stat.size.toString(16)}-${stat.mtimeMs.toString(16)}"`;
      const headers = {
        "content-type": MIME[extname(target).toLowerCase()] || "application/octet-stream",
        "cache-control": "no-cache", "x-content-type-options": "nosniff",
        "accept-ranges": "bytes", etag, "last-modified": stat.mtime.toUTCString()
      };
      const matches = request.headers["if-none-match"]?.split(",").map(x => x.trim());
      if (matches?.includes(etag) || matches?.includes("*")) {
        response.writeHead(304, headers); response.end(); return;
      }
      // Weak validators cannot authorize If-Range continuation.
      let range;
      if (request.headers.range && !request.headers["if-range"] && request.method === "GET") {
        range = byteRange(request.headers.range, stat.size);
        if (!range) return reply(416, "Range not satisfiable", { "content-range": `bytes */${stat.size}` });
        headers["content-range"] = `bytes ${range.start}-${range.end}/${stat.size}`;
      }
      headers["content-length"] = range ? range.end - range.start + 1 : stat.size;
      response.writeHead(range ? 206 : 200, headers);
      if (request.method === "HEAD") { response.end(); return; }
      const stream = file.createReadStream(range || {});
      file = undefined;
      response.once("close", () => stream.destroy());
      stream.once("error", () => response.destroy());
      stream.pipe(response);
    } catch (error) {
      if (response.headersSent) response.destroy();
      else reply(["ENOENT", "ENOTDIR", "EACCES", "ELOOP"].includes(error.code) ? 404 : 500, "Not found");
    } finally {
      if (file) await file.close().catch(() => {});
    }
  });
}

export function startServer({ host = "127.0.0.1", port = Number(process.env.PORT || 5173), root = __dirname } = {}) {
  const server = createStaticServer(root);
  const tryListen = candidate => {
    const onError = error => {
      server.removeListener("listening", onListening);
      if (error.code === "EADDRINUSE" && candidate < port + 20) tryListen(candidate + 1);
      else throw error;
    };
    const onListening = () => {
      server.removeListener("error", onError);
      console.log(`绯线远征已启动: http://${host}:${server.address().port}/`);
    };
    server.once("error", onError); server.once("listening", onListening);
    server.listen(candidate, host);
  };
  tryListen(port);
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) startServer();
