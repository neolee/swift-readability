// CLI/scripts/mozilla-bridge.js
//
// Runs Mozilla Readability.js on a local HTML file and emits JSON to stdout.
//
// Usage:
//   node mozilla-bridge.js <path-to-source.html> [page-url]
//
// Requires Node.js. Uses CJS + jsdom (not compatible with Deno).
// First-time setup: run `npm install` in CLI/scripts/
// Stdout: JSON object with keys:
//   content, title, byline, excerpt, siteName, dir, lang, publishedTime
//
// Exit codes:
//   0  success
//   1  usage / argument error
//   2  Readability.parse() returned null (not readable)

const vm   = require("vm");
const path = require("path");
const fs   = require("fs");

const sourcePath = process.argv[2];
const pageURL = process.argv[3];
if (!sourcePath) {
  process.stderr.write("Error: missing argument — usage: mozilla-bridge.js <path-to-source.html> [page-url]\n");
  process.exit(1);
}

// Locate directories
const refDir = path.resolve(__dirname, "..", "..", "ref", "mozilla-readability");

// Load Readability into the real global context.
// JSDOMParser (Mozilla's lightweight parser) fails on real-world HTML with
// complex inline scripts. We use jsdom instead for robust HTML5 parsing.
// Readability is loaded via runInThisContext so its `this`-based globals work.
vm.runInThisContext(fs.readFileSync(path.join(refDir, "Readability.js"), "utf8"));

// jsdom is installed in CLI/scripts/node_modules/ via `npm install`
let JSDOM, VirtualConsole;
try {
  ({ JSDOM, VirtualConsole } = require("jsdom"));
} catch (e) {
  process.stderr.write("Error: jsdom not found. Run: npm install  (in CLI/scripts/)\n");
  process.exit(1);
}

let html;
try {
  html = fs.readFileSync(sourcePath, { encoding: "utf8" });
} catch (e) {
  process.stderr.write("Error reading source file: " + e.message + "\n");
  process.exit(1);
}

// Suppress "Could not parse CSS stylesheet" — jsdom's CSS parser does not yet
// support some modern properties (color-mix, @starting-style, etc.) found on
// many real-world pages. These errors are unrelated to HTML parsing and do not
// affect Readability extraction. All other jsdom errors are forwarded to stderr.
const vc = new VirtualConsole();
vc.on("jsdomError", (e) => {
  if (!String(e.message).startsWith("Could not parse CSS")) {
    process.stderr.write("jsdom: " + e.message + "\n");
  }
});

let doc;
try {
  const jsdomOptions = { virtualConsole: vc };
  if (pageURL) {
    jsdomOptions.url = pageURL;
  }
  doc = new JSDOM(html, jsdomOptions).window.document;
} catch (e) {
  process.stderr.write("Error parsing HTML: " + e.message + "\n");
  process.exit(1);
}

const reader = new global.Readability(doc);
const result = reader.parse();

if (!result) {
  process.stderr.write("Readability.parse() returned null — page may not be readable\n");
  process.exit(2);
}

function nullable(v) {
  return v != null ? v : null;
}

const output = {
  content:       result.content       != null ? result.content       : "",
  title:         result.title         != null ? result.title         : "",
  byline:        nullable(result.byline),
  excerpt:       nullable(result.excerpt),
  siteName:      nullable(result.siteName),
  dir:           nullable(result.dir),
  lang:          nullable(result.lang),
  publishedTime: nullable(result.publishedTime),
};

process.stdout.write(JSON.stringify(output) + "\n");
