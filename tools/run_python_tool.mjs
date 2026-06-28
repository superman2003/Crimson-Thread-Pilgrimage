import { existsSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const [, , script, ...args] = process.argv;

if (!script) {
  console.error("Usage: node tools/run_python_tool.mjs <script.py> [...args]");
  process.exit(2);
}

const candidates = [];

if (process.env.PYTHON) {
  candidates.push({ command: process.env.PYTHON, args: [] });
}

candidates.push(
  { command: "python", args: [] },
  { command: "python3", args: [] },
  { command: "py", args: ["-3"] },
);

const codexPython = path.join(
  os.homedir(),
  ".cache",
  "codex-runtimes",
  "codex-primary-runtime",
  "dependencies",
  "python",
  process.platform === "win32" ? "python.exe" : "bin/python",
);

if (existsSync(codexPython)) {
  candidates.push({ command: codexPython, args: [] });
}

const scriptPath = path.resolve(script);
let lastError = "";

for (const candidate of candidates) {
  const version = spawnSync(candidate.command, [...candidate.args, "--version"], {
    encoding: "utf8",
    shell: false,
  });
  if (version.error || version.status !== 0) {
    lastError = version.error?.message || version.stderr || version.stdout || `status ${version.status}`;
    continue;
  }

  const result = spawnSync(candidate.command, [...candidate.args, scriptPath, ...args], {
    encoding: "utf8",
    shell: false,
    stdio: "inherit",
  });
  if (result.error) {
    lastError = result.error.message;
    continue;
  }
  process.exit(result.status ?? 0);
}

console.error(`No usable Python runtime found. Last error: ${lastError}`);
console.error("Set PYTHON to a Python executable path, or install Python 3.");
process.exit(127);
