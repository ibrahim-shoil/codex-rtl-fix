import { connectPageCdp } from "./cdp-client.mjs";
import { RTL_PAYLOAD } from "./rtl-payload.mjs";
import { appendFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const logPath = join(scriptDir, "rtl-injector.log");
const errorLogPath = join(scriptDir, "rtl-injector.err.log");

const args = process.argv.slice(2);
const portIndex = args.indexOf("--port");
const port = Number(portIndex >= 0 ? args[portIndex + 1] : 0);

if (!Number.isInteger(port) || port < 1024 || port > 65535) {
  console.error("Usage: node rtl-injector.mjs --port <1024-65535>");
  process.exit(2);
}

const endpoint = `http://127.0.0.1:${port}`;
const injectedTargets = new Set();
let connectedOnce = false;
let unavailableSince = Date.now();
let pollInProgress = false;

function log(record) {
  appendFileSync(logPath, `${JSON.stringify(record)}\n`, "utf8");
}

function logError(error) {
  appendFileSync(errorLogPath, `${new Date().toISOString()} ${error.stack || error.message}\n`, "utf8");
}

function isCodexPage(target) {
  if (target.type !== "page" || !target.webSocketDebuggerUrl) return false;
  return /^(app|file):/i.test(target.url ?? "") ||
    /codex|chatgpt/i.test(`${target.title ?? ""} ${target.url ?? ""}`);
}

async function inject(target) {
  const injectionKey = `${target.id}:${target.url ?? ""}`;
  if (injectedTargets.has(injectionKey)) return;
  const client = await connectPageCdp(target.webSocketDebuggerUrl, port);

  try {
    const result = await client.request("Runtime.evaluate", {
      expression: RTL_PAYLOAD,
      returnByValue: true
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.text || "RTL payload evaluation failed.");
    }
    injectedTargets.add(injectionKey);
    connectedOnce = true;
    log({
      event: "rtl-injected",
      targetId: target.id,
      url: target.url,
      time: new Date().toISOString()
    });
  } finally {
    client.close();
  }
}

async function poll() {
  if (pollInProgress) return;
  pollInProgress = true;
  try {
    const response = await fetch(`${endpoint}/json/list`, {
      signal: AbortSignal.timeout(1500)
    });
    if (!response.ok) throw new Error(`CDP returned ${response.status}`);

    const targets = await response.json();
    unavailableSince = Date.now();
    for (const target of targets.filter(isCodexPage)) {
      await inject(target);
    }
  } catch (error) {
    if (connectedOnce && Date.now() - unavailableSince > 12_000) {
      process.exit(0);
    }
    if (!connectedOnce && Date.now() - unavailableSince > 45_000) {
      logError(error);
      process.exit(1);
    }
  } finally {
    pollInProgress = false;
  }
}

await poll();
setInterval(poll, 800);
