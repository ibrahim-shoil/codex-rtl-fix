import { RTL_PAYLOAD } from "./rtl-payload.mjs";
import { connectPageCdp } from "./cdp-client.mjs";

const port = Number(process.argv[2]);
if (!Number.isInteger(port)) {
  console.error("Usage: node rtl-apply-once.mjs <port>");
  process.exit(2);
}

const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then((res) => res.json());
const page = targets.find((target) => target.type === "page" && target.url?.startsWith("app:"));
if (!page) throw new Error("Codex page target was not found.");

const client = await connectPageCdp(page.webSocketDebuggerUrl, port);
const result = await client.request("Runtime.evaluate", {
  expression: RTL_PAYLOAD,
  returnByValue: true
});
client.close();

if (result.exceptionDetails) {
  console.error(JSON.stringify(result, null, 2));
  process.exit(1);
}
console.log("RTL payload applied to the live Codex page.");
