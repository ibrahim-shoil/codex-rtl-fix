import assert from "node:assert/strict";
import { RTL_PAYLOAD } from "./rtl-payload.mjs";

assert.match(RTL_PAYLOAD, /setAttribute\("dir", "auto"\)/);
assert.match(RTL_PAYLOAD, /setAttribute\("dir", "ltr"\)/);
assert.match(RTL_PAYLOAD, /unicode-bidi:plaintext/);
assert.match(RTL_PAYLOAD, /unicode-bidi:isolate/);
assert.match(RTL_PAYLOAD, /p\[class\*='_markdownText_'\]/);
assert.match(RTL_PAYLOAD, /\.inline-markdown/);
assert.doesNotMatch(RTL_PAYLOAD, /\.ProseMirror/);
assert.doesNotMatch(RTL_PAYLOAD, /\[contenteditable='true'\]/);
assert.doesNotMatch(RTL_PAYLOAD, /\[data-message-author-role\]/);
assert.match(RTL_PAYLOAD, /MutationObserver/);
assert.match(RTL_PAYLOAD, /setTimeout\(install, 3000\)/);

new Function(RTL_PAYLOAD);

console.log("RTL payload syntax and direction contracts passed.");
