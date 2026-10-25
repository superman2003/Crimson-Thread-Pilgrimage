import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, symlink, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { once } from "node:events";
import { request } from "node:http";
import { createStaticServer } from "../server.js";

test("preview serves media and survives malformed URLs and escaped paths", async () => {
  const directory = await mkdtemp(join(tmpdir(), "pilgrimage-http-"));
  const root = join(directory, "public");
  await mkdir(root); await mkdir(join(directory, "public-other"));
  await writeFile(join(root, "index.html"), "<h1>巡礼</h1>");
  await writeFile(join(root, "sound.ogg"), "0123456789");
  await writeFile(join(root, "空 格.json"), "{}");
  await writeFile(join(directory, "public-other", "secret"), "private");
  await symlink(join(directory, "public-other"), join(root, "escape"));
  await mkdir(join(root, ".git")); await writeFile(join(root, ".git", "config"), "private");
  const server = createStaticServer(root);
  server.listen(0, "127.0.0.1"); await once(server, "listening");
  const port = server.address().port;
  const get = (path, options = {}) => new Promise((resolve, reject) => {
    const req = request({ host: "127.0.0.1", port, path, ...options }, res => {
      const chunks = []; res.on("data", chunk => chunks.push(chunk));
      res.on("end", () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks).toString() }));
    });
    req.on("error", reject); req.end();
  });
  try {
    const page = await get("/?v=2"); assert.equal(page.status, 200); assert.match(page.body, /巡礼/);
    assert.equal((await get("/%E7%A9%BA%20%E6%A0%BC.json")).body, "{}");
    for (const path of ["/%", "/%E0%A4%A", "/%00", "/%5csecret"]) assert.equal((await get(path)).status, 400, path);
    for (const path of ["/missing", "/escape/secret", "/%2e%2e%2fpublic-other/secret", "/.git/config", "/escape"]) assert.equal((await get(path)).status, 404, path);
    assert.equal((await get("/", { method: "POST" })).status, 405);
    const head = await get("/sound.ogg", { method: "HEAD" });
    assert.equal(head.body, ""); assert.equal(head.headers["content-length"], "10");
    assert.equal(head.headers["content-type"], "audio/ogg");
    for (const [range, expected] of [["bytes=2-4", "234"], ["bytes=7-", "789"], ["bytes=-3", "789"], ["bytes=8-999", "89"], ["bytes=-99", "0123456789"]]) {
      const result = await get("/sound.ogg", { headers: { range } });
      assert.equal(result.status, 206); assert.equal(result.body, expected);
      assert.equal(Number(result.headers["content-length"]), expected.length);
    }
    for (const range of ["bytes=10-", "bytes=5-2", "bytes=-0", "bytes=", "bytes=0-1,4-5", "bytes=999999999999999999999-"]) {
      const result = await get("/sound.ogg", { headers: { range } });
      assert.equal(result.status, 416, range); assert.equal(result.headers["content-range"], "bytes */10");
    }
    const unchanged = await get("/sound.ogg", { headers: { "if-none-match": head.headers.etag } });
    assert.equal(unchanged.status, 304); assert.equal(unchanged.body, "");
    assert.equal((await get("/sound.ogg", { headers: { range: "bytes=2-4", "if-range": head.headers.etag } })).status, 200);
    await writeFile(join(root, "empty"), "");
    assert.equal((await get("/empty", { headers: { range: "bytes=0-" } })).status, 416);
    assert.equal((await get("/")).status, 200);
  } finally { server.closeAllConnections(); await new Promise(done => server.close(done)); await rm(directory, { recursive: true, force: true }); }
});
