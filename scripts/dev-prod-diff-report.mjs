#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

const DEFAULT_PROD_ORIGIN = "https://dave-blake.com";
const DEFAULT_DEV_ORIGIN = "https://dev.dave-blake.com";
const DEFAULT_PATHS_FILE = "data/qa/url-paths.txt";
const DEFAULT_IGNORE_FILE = "data/qa/ignore-checks.txt";
const DEFAULT_OUT_ROOT = "data/qa/reports";

function parseArgs(argv) {
  const args = {
    prod: process.env.PROD_ORIGIN || DEFAULT_PROD_ORIGIN,
    dev: process.env.DEV_ORIGIN || DEFAULT_DEV_ORIGIN,
    paths: process.env.DIFF_PATHS_FILE || DEFAULT_PATHS_FILE,
    ignore: process.env.DIFF_IGNORE_FILE || DEFAULT_IGNORE_FILE,
    outRoot: process.env.DIFF_OUT_ROOT || DEFAULT_OUT_ROOT,
    failOnCritical: process.env.FAIL_ON_CRITICAL === "1",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--prod") {
      args.prod = argv[i + 1];
      i += 1;
    } else if (arg === "--dev") {
      args.dev = argv[i + 1];
      i += 1;
    } else if (arg === "--paths") {
      args.paths = argv[i + 1];
      i += 1;
    } else if (arg === "--ignore") {
      args.ignore = argv[i + 1];
      i += 1;
    } else if (arg === "--out-root") {
      args.outRoot = argv[i + 1];
      i += 1;
    } else if (arg === "--fail-on-critical") {
      args.failOnCritical = true;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }
  }

  return args;
}

function printHelp() {
  const text = `
Usage: node scripts/dev-prod-diff-report.mjs [options]

Options:
  --prod <origin>            Production origin (default: ${DEFAULT_PROD_ORIGIN})
  --dev <origin>             Development origin (default: ${DEFAULT_DEV_ORIGIN})
  --paths <file>             Path list file (default: ${DEFAULT_PATHS_FILE})
  --ignore <file>            Ignore checks file (default: ${DEFAULT_IGNORE_FILE})
  --out-root <dir>           Report root dir (default: ${DEFAULT_OUT_ROOT})
  --fail-on-critical         Exit with code 1 if critical differences are found
  -h, --help                 Show help

Environment overrides:
  PROD_ORIGIN, DEV_ORIGIN, DIFF_PATHS_FILE, DIFF_IGNORE_FILE, DIFF_OUT_ROOT, FAIL_ON_CRITICAL
`;
  process.stdout.write(text);
}

function nowIsoCompact() {
  return new Date().toISOString().replace(/[:.]/g, "-");
}

function normalizeRoutePath(input) {
  const raw = (input || "").trim();
  if (!raw) return "/";
  let value = raw;
  if (/^https?:\/\//i.test(value)) {
    value = new URL(value).pathname || "/";
  }
  if (!value.startsWith("/")) value = `/${value}`;
  value = value.replace(/\/{2,}/g, "/");
  value = value.replace(/\/index\.html$/i, "/");
  if (value !== "/" && !/\.[a-z0-9]+$/i.test(value) && !value.endsWith("/")) {
    value = `${value}/`;
  }
  return value;
}

function normalizeComparablePath(input) {
  return normalizeRoutePath(input);
}

async function readListFile(filePath) {
  const content = await fs.readFile(filePath, "utf8");
  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}

function parseAttributes(tag) {
  const attrs = {};
  const attrRegex = /([a-zA-Z_:][\w:.-]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+))/g;
  let match;
  while ((match = attrRegex.exec(tag)) !== null) {
    const key = match[1].toLowerCase();
    const value = match[3] ?? match[4] ?? match[5] ?? "";
    attrs[key] = value;
  }
  return attrs;
}

function htmlDecode(input) {
  if (!input) return "";
  return input
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function cleanText(input) {
  return htmlDecode(input || "")
    .replace(/\s+/g, " ")
    .trim();
}

function extractFirst(regex, text) {
  const match = text.match(regex);
  return match ? match[1] : "";
}

function extractTitle(html) {
  return cleanText(extractFirst(/<title[^>]*>([\s\S]*?)<\/title>/i, html));
}

function extractMetaContent(html, metaName) {
  const lower = metaName.toLowerCase();
  const metaRegex = /<meta\b[^>]*>/gi;
  let match;
  while ((match = metaRegex.exec(html)) !== null) {
    const attrs = parseAttributes(match[0]);
    const name = (attrs.name || attrs.property || "").toLowerCase();
    if (name === lower) {
      return cleanText(attrs.content || "");
    }
  }
  return "";
}

function extractCanonicalHref(html) {
  const linkRegex = /<link\b[^>]*>/gi;
  let match;
  while ((match = linkRegex.exec(html)) !== null) {
    const attrs = parseAttributes(match[0]);
    const rel = (attrs.rel || "").toLowerCase();
    if (rel.split(/\s+/).includes("canonical")) {
      return (attrs.href || "").trim();
    }
  }
  return "";
}

function stripTags(input) {
  return input.replace(/<[^>]+>/g, " ");
}

function extractFirstH1(html) {
  return cleanText(stripTags(extractFirst(/<h1[^>]*>([\s\S]*?)<\/h1>/i, html)));
}

function extractJsonLdTypes(html) {
  const scriptRegex =
    /<script\b[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  const types = new Set();

  const collectTypes = (value) => {
    if (Array.isArray(value)) {
      value.forEach(collectTypes);
      return;
    }
    if (value && typeof value === "object") {
      if (Object.hasOwn(value, "@type")) {
        const t = value["@type"];
        if (Array.isArray(t)) {
          t.forEach((item) => types.add(String(item)));
        } else {
          types.add(String(t));
        }
      }
      Object.values(value).forEach(collectTypes);
    }
  };

  let match;
  while ((match = scriptRegex.exec(html)) !== null) {
    const raw = match[1].trim();
    if (!raw) continue;
    try {
      const parsed = JSON.parse(raw);
      collectTypes(parsed);
    } catch {
      // Ignore invalid JSON-LD blocks.
    }
  }

  return Array.from(types).sort().join("|");
}

function getBodyHtml(html) {
  const body = html.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
  return body ? body[1] : html;
}

function normalizedBodyTextHash(html, prodOrigin, devOrigin) {
  const body = getBodyHtml(html)
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, " ");

  const domainPattern = new RegExp(
    `${escapeRegex(prodOrigin)}|${escapeRegex(devOrigin)}`,
    "gi"
  );
  const normalized = cleanText(stripTags(body))
    .replace(domainPattern, "<origin>")
    .toLowerCase();

  return crypto.createHash("sha256").update(normalized).digest("hex");
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function fetchPage(url) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  try {
    const response = await fetch(url, {
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "user-agent": "dave-blake-dev-prod-diff/1.0",
      },
    });
    const html = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      finalUrl: response.url,
      html,
      error: "",
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      finalUrl: url,
      html: "",
      error: String(error?.message || error),
    };
  } finally {
    clearTimeout(timeout);
  }
}

function createPageSnapshot(fetchResult, prodOrigin, devOrigin) {
  if (!fetchResult.html) {
    return {
      title: "",
      description: "",
      robots: "",
      canonicalHref: "",
      canonicalPath: "",
      h1: "",
      jsonLdTypes: "",
      imgCount: 0,
      vimeoCount: 0,
      bodyHash: "",
    };
  }

  const canonicalHref = extractCanonicalHref(fetchResult.html);
  const canonicalPath = canonicalHref
    ? normalizeComparablePath(new URL(canonicalHref, fetchResult.finalUrl).pathname)
    : "";

  return {
    title: extractTitle(fetchResult.html),
    description: extractMetaContent(fetchResult.html, "description"),
    robots: extractMetaContent(fetchResult.html, "robots"),
    canonicalHref,
    canonicalPath,
    h1: extractFirstH1(fetchResult.html),
    jsonLdTypes: extractJsonLdTypes(fetchResult.html),
    imgCount: (fetchResult.html.match(/<img\b/gi) || []).length,
    vimeoCount: (fetchResult.html.match(/player\.vimeo\.com|vimeo\.com\/video/gi) || [])
      .length,
    bodyHash: normalizedBodyTextHash(fetchResult.html, prodOrigin, devOrigin),
  };
}

function compareField(pagePath, check, prodValue, devValue, severity, note = "") {
  if (String(prodValue) === String(devValue)) return null;
  return { path: pagePath, check, severity, prod: String(prodValue), dev: String(devValue), note };
}

function shouldIgnoreRobots(prodRobots, devRobots) {
  const prodHasNoIndex = /noindex/i.test(prodRobots);
  const devHasNoIndex = /noindex/i.test(devRobots);
  return !prodHasNoIndex && devHasNoIndex;
}

function applyIgnoreRule(diff, ignoreChecks) {
  if (ignoreChecks.has(diff.check)) {
    return { ...diff, severity: "ignored", note: `${diff.note} ignored by config`.trim() };
  }
  return diff;
}

function csvEscape(value) {
  const text = String(value ?? "");
  if (/[",\n]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
}

function renderSummaryMarkdown({
  generatedAt,
  prodOrigin,
  devOrigin,
  pageCount,
  critical,
  warn,
  ignored,
}) {
  const lines = [];
  lines.push("# Dev vs Prod Diff Report");
  lines.push("");
  lines.push(`Generated: ${generatedAt}`);
  lines.push(`Prod: ${prodOrigin}`);
  lines.push(`Dev: ${devOrigin}`);
  lines.push(`Pages checked: ${pageCount}`);
  lines.push(`Critical: ${critical.length}`);
  lines.push(`Warn: ${warn.length}`);
  lines.push(`Ignored: ${ignored.length}`);
  lines.push("");

  const renderSection = (title, items) => {
    lines.push(`## ${title}`);
    if (!items.length) {
      lines.push("None");
      lines.push("");
      return;
    }
    lines.push("| Path | Check | Prod | Dev | Note |");
    lines.push("|---|---|---|---|---|");
    for (const item of items) {
      lines.push(
        `| ${item.path} | ${item.check} | ${item.prod || "-"} | ${item.dev || "-"} | ${
          item.note || "-"
        } |`
      );
    }
    lines.push("");
  };

  renderSection("Critical", critical);
  renderSection("Warn", warn);
  renderSection("Ignored", ignored);

  return `${lines.join("\n")}\n`;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const prodOrigin = args.prod.replace(/\/+$/, "");
  const devOrigin = args.dev.replace(/\/+$/, "");

  const pathsRaw = await readListFile(args.paths);
  const paths = Array.from(new Set(pathsRaw.map(normalizeRoutePath)));

  let ignoreChecks = new Set();
  try {
    const ignoreItems = await readListFile(args.ignore);
    ignoreChecks = new Set(ignoreItems);
  } catch {
    // Ignore missing ignore file.
  }

  const diffs = [];
  const pageSnapshots = [];

  for (const pagePath of paths) {
    const prodUrl = `${prodOrigin}${pagePath}`;
    const devUrl = `${devOrigin}${pagePath}`;

    const [prodFetch, devFetch] = await Promise.all([fetchPage(prodUrl), fetchPage(devUrl)]);

    const prodFinalPath = normalizeComparablePath(new URL(prodFetch.finalUrl).pathname);
    const devFinalPath = normalizeComparablePath(new URL(devFetch.finalUrl).pathname);

    pageSnapshots.push({
      path: pagePath,
      prod: {
        status: prodFetch.status,
        finalUrl: prodFetch.finalUrl,
      },
      dev: {
        status: devFetch.status,
        finalUrl: devFetch.finalUrl,
      },
    });

    if (!prodFetch.ok || prodFetch.status >= 400) {
      diffs.push({
        path: pagePath,
        check: "prod_status",
        severity: "critical",
        prod: String(prodFetch.status),
        dev: String(devFetch.status),
        note: prodFetch.error || "Production page is not OK",
      });
      continue;
    }

    if (!devFetch.ok || devFetch.status >= 400) {
      diffs.push({
        path: pagePath,
        check: "dev_status",
        severity: "critical",
        prod: String(prodFetch.status),
        dev: String(devFetch.status),
        note: devFetch.error || "Development page is not OK",
      });
      continue;
    }

    if (prodFinalPath !== devFinalPath) {
      diffs.push({
        path: pagePath,
        check: "final_path",
        severity: "critical",
        prod: prodFinalPath,
        dev: devFinalPath,
        note: "Final routed paths differ",
      });
    }

    const prodSnapshot = createPageSnapshot(prodFetch, prodOrigin, devOrigin);
    const devSnapshot = createPageSnapshot(devFetch, prodOrigin, devOrigin);

    const directChecks = [
      compareField(pagePath, "title", prodSnapshot.title, devSnapshot.title, "warn"),
      compareField(
        pagePath,
        "meta_description",
        prodSnapshot.description,
        devSnapshot.description,
        "warn"
      ),
      compareField(pagePath, "h1", prodSnapshot.h1, devSnapshot.h1, "critical"),
      compareField(
        pagePath,
        "canonical_path",
        prodSnapshot.canonicalPath,
        devSnapshot.canonicalPath,
        "critical"
      ),
      compareField(
        pagePath,
        "jsonld_types",
        prodSnapshot.jsonLdTypes,
        devSnapshot.jsonLdTypes,
        "warn"
      ),
      compareField(pagePath, "img_count", prodSnapshot.imgCount, devSnapshot.imgCount, "warn"),
      compareField(
        pagePath,
        "vimeo_embed_count",
        prodSnapshot.vimeoCount,
        devSnapshot.vimeoCount,
        "warn"
      ),
      compareField(
        pagePath,
        "body_text_hash",
        prodSnapshot.bodyHash,
        devSnapshot.bodyHash,
        "warn"
      ),
    ].filter(Boolean);

    for (const diff of directChecks) {
      diffs.push(applyIgnoreRule(diff, ignoreChecks));
    }

    if (prodSnapshot.robots !== devSnapshot.robots) {
      const baseDiff = {
        path: pagePath,
        check: "robots_meta",
        severity: "warn",
        prod: prodSnapshot.robots,
        dev: devSnapshot.robots,
        note: "",
      };
      if (shouldIgnoreRobots(prodSnapshot.robots, devSnapshot.robots)) {
        diffs.push({
          ...baseDiff,
          severity: "ignored",
          note: "expected staging noindex behavior",
        });
      } else {
        diffs.push(applyIgnoreRule(baseDiff, ignoreChecks));
      }
    }
  }

  const generatedAt = new Date().toISOString();
  const outDir = path.join(args.outRoot, nowIsoCompact());
  await fs.mkdir(outDir, { recursive: true });

  const critical = diffs.filter((item) => item.severity === "critical");
  const warn = diffs.filter((item) => item.severity === "warn");
  const ignored = diffs.filter((item) => item.severity === "ignored");

  const summary = renderSummaryMarkdown({
    generatedAt,
    prodOrigin,
    devOrigin,
    pageCount: paths.length,
    critical,
    warn,
    ignored,
  });

  const csvHeader = "severity,path,check,prod,dev,note\n";
  const csvBody = diffs
    .map((item) =>
      [
        item.severity,
        item.path,
        item.check,
        csvEscape(item.prod),
        csvEscape(item.dev),
        csvEscape(item.note),
      ].join(",")
    )
    .join("\n");

  await Promise.all([
    fs.writeFile(path.join(outDir, "summary.md"), summary, "utf8"),
    fs.writeFile(path.join(outDir, "diffs.csv"), `${csvHeader}${csvBody}\n`, "utf8"),
    fs.writeFile(
      path.join(outDir, "snapshots.json"),
      `${JSON.stringify(pageSnapshots, null, 2)}\n`,
      "utf8"
    ),
    fs.writeFile(
      path.join(args.outRoot, "latest.txt"),
      `${path.relative(args.outRoot, outDir)}\n`,
      "utf8"
    ),
  ]);

  process.stdout.write(`Report directory: ${outDir}\n`);
  process.stdout.write(`Critical: ${critical.length}\n`);
  process.stdout.write(`Warn: ${warn.length}\n`);
  process.stdout.write(`Ignored: ${ignored.length}\n`);
  process.stdout.write(`Summary: ${path.join(outDir, "summary.md")}\n`);

  if (args.failOnCritical && critical.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  process.stderr.write(`${String(error?.stack || error)}\n`);
  process.exit(1);
});
