import { connectPageCdp } from "./cdp-client.mjs";

const port = Number(process.argv[2]);
if (!Number.isInteger(port)) {
  console.error("Usage: node rtl-diagnose.mjs <port>");
  process.exit(2);
}

const targets = await fetch(`http://127.0.0.1:${port}/json/list`).then((res) => res.json());
const page = targets.find((target) => target.type === "page" && target.url?.startsWith("app:"));
if (!page) throw new Error("Codex page target was not found.");

const client = await connectPageCdp(page.webSocketDebuggerUrl, port);
const result = await client.request("Runtime.evaluate", {
  returnByValue: true,
  expression: String.raw`
        (() => {
          const arabic = /[\u0600-\u06ff]/u;
          const elements = [...document.querySelectorAll("body *")];
          const leaves = elements.filter((element) => {
            if (!arabic.test(element.textContent || "")) return false;
            return ![...element.children].some((child) => arabic.test(child.textContent || ""));
          });
          return {
            rootFlag: document.documentElement.getAttribute("data-codex-rtl-fix"),
            stylePresent: Boolean(document.getElementById("codex-rtl-fix-style")),
            autoDirectionCount: document.querySelectorAll('[dir="auto"]').length,
            ltrDirectionCount: document.querySelectorAll('[dir="ltr"]').length,
            arabicLeaves: leaves.slice(-40).map((element) => {
              const style = getComputedStyle(element);
              return {
                tag: element.tagName,
                className: String(element.className || "").slice(0, 240),
                dir: element.getAttribute("dir"),
                direction: style.direction,
                textAlign: style.textAlign,
                unicodeBidi: style.unicodeBidi,
                text: (element.textContent || "").trim().slice(0, 260),
                parentTag: element.parentElement?.tagName ?? null,
                parentClass: String(element.parentElement?.className || "").slice(0, 240)
              };
            })
          };
        })()
      `
});
client.close();
console.log(JSON.stringify(result.result?.value ?? result, null, 2));
