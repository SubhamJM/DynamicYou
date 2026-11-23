// ==UserScript==
// @name           dynamic-you-zen
// @description    re-applies Dynamic You's wallpaper colours (chrome/dynamic-you-zen.css and dynamic-you-sites.css) each time they are rendered again
// ==/UserScript==

// userChrome.css and userContent.css import the same files, but zen only
// reads those once, at startup. this registers each as an agent sheet, whose
// !important outranks the stale copies, and swaps it for each new render. a
// render is taken once its end marker is in, or once it has held still for a poll

import { setInterval } from "resource://gre/modules/Timer.sys.mjs";

const CHROME = Services.dirsvc.get("UChrm", Ci.nsIFile).path;
const POLL_MS = 1000;

const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);

const SHEETS = [
  // zen's own window. agent sheets reach web pages too, so this one is kept to zen's
  {
    file: "dynamic-you-zen.css",
    end: "/* lucid-zen: end */",
    wrap: css => `@-moz-document url-prefix("chrome:") {\n${css}\n}\n`,
  },
  // web pages: each site's rules already sit in their own @-moz-document block
  {
    file: "dynamic-you-sites.css",
    end: "/* lucid-sites: end */",
    wrap: css => css,
  },
].map(s => ({ ...s, path: PathUtils.join(CHROME, s.file), sheet: null, seen: "", pending: null }));

let busy = false;

function drop(s) {
  if (s.sheet && sss.sheetRegistered(s.sheet, sss.AGENT_SHEET)) {
    sss.unregisterSheet(s.sheet, sss.AGENT_SHEET);
  }
  s.sheet = null;
}

function apply(s, css) {
  const uri = Services.io.newURI("data:text/css;charset=utf-8," + encodeURIComponent(s.wrap(css)));
  try {
    sss.loadAndRegisterSheet(uri, sss.AGENT_SHEET);
  } catch (e) {
    console.error(`dynamic-you-zen: could not apply ${s.file}`, e);
    return;
  }
  // the new sheet goes in before the old one leaves, so nothing flashes
  drop(s);
  s.sheet = uri;
}

async function poll(s) {
  let info;
  try {
    info = await IOUtils.stat(s.path);
  } catch {
    // no colours, or the template was removed: back to zen's own
    drop(s);
    s.seen = "";
    s.pending = null;
    return;
  }
  const key = `${info.lastModified}:${info.size}`;
  if (key === s.seen) {
    if (s.pending !== null) {
      apply(s, s.pending);
      s.pending = null;
    }
    return;
  }
  s.seen = key;
  s.pending = null;
  const css = await IOUtils.readUTF8(s.path);
  if (css.includes(s.end)) {
    apply(s, css);
  } else {
    s.pending = css;
  }
}

async function tick() {
  if (busy) {
    return;
  }
  busy = true;
  try {
    for (const s of SHEETS) {
      try {
        await poll(s);
      } catch (e) {
        console.error(`dynamic-you-zen: ${s.file}`, e);
      }
    }
  } finally {
    busy = false;
  }
}

tick();
setInterval(tick, POLL_MS);
