export const RTL_PAYLOAD = String.raw`
(() => {
  const STYLE_ID = "codex-rtl-fix-style";
  const ROOT_FLAG = "data-codex-rtl-fix";
  const AUTO_SELECTOR = [
    "p[class*='_markdownText_']",
    "li[class*='_markdownText_']",
    "blockquote[class*='_markdownText_']",
    "h1[class*='_markdownText_']",
    "h2[class*='_markdownText_']",
    "h3[class*='_markdownText_']",
    "h4[class*='_markdownText_']",
    "h5[class*='_markdownText_']",
    "h6[class*='_markdownText_']",
    "td[class*='_markdownText_']",
    "th[class*='_markdownText_']",
    "span[class*='_inlineMarkdown_']",
    ".inline-markdown"
  ].join(",");
  const LTR_SELECTOR = [
    "pre",
    "code",
    "kbd",
    "samp",
    ".monaco-editor",
    ".xterm",
    "[data-language]"
  ].join(",");

  function installStyle() {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = [
      "p[class*='_markdownText_'],li[class*='_markdownText_'],blockquote[class*='_markdownText_'],",
      "h1[class*='_markdownText_'],h2[class*='_markdownText_'],h3[class*='_markdownText_'],h4[class*='_markdownText_'],h5[class*='_markdownText_'],h6[class*='_markdownText_'],",
      "td[class*='_markdownText_'],th[class*='_markdownText_'],span[class*='_inlineMarkdown_'],.inline-markdown",
      "{unicode-bidi:plaintext;text-align:start;}",
      "pre,code,kbd,samp,.monaco-editor,.xterm,[data-language]",
      "{direction:ltr!important;unicode-bidi:isolate!important;text-align:left!important;}"
    ].join("");
    (document.head || document.documentElement).appendChild(style);
  }

  function applyDirection(scope) {
    if (!(scope instanceof Element || scope instanceof Document)) return;
    const candidates = [];
    if (scope instanceof Element && scope.matches(AUTO_SELECTOR)) {
      candidates.push(scope);
    }
    candidates.push(...scope.querySelectorAll(AUTO_SELECTOR));
    for (const element of candidates) {
      if (!element.closest(LTR_SELECTOR)) {
        element.setAttribute("dir", "auto");
      }
    }
    for (const element of scope.querySelectorAll(LTR_SELECTOR)) {
      element.setAttribute("dir", "ltr");
    }
  }

  function install() {
    installStyle();
    document.documentElement.setAttribute(ROOT_FLAG, "1");
    applyDirection(document);

    const observer = new MutationObserver((records) => {
      for (const record of records) {
        for (const node of record.addedNodes) {
          if (node instanceof Element) applyDirection(node);
        }
      }
    });
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", install, { once: true });
  } else {
    setTimeout(install, 3000);
  }
})();
`;
