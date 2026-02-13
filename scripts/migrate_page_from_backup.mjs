#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs/promises";
import fssync from "node:fs";
import path from "node:path";

const DEFAULT_BACKUP_ROOT = "/Users/daveblake/site-backups/dave-blake-sspro";

function usage() {
  process.stderr.write(
    [
      "Usage:",
      "  node scripts/migrate_page_from_backup.mjs --source <backup-html> --dest <repo-html> --asset-dir <assets/images/pages subdir> [--backup-root <dir>]",
      "",
      "Example:",
      "  node scripts/migrate_page_from_backup.mjs \\",
      "    --source /Users/daveblake/site-backups/dave-blake-sspro/dave-blake.com/model-tests.html \\",
      "    --dest model-tests/index.html \\",
      "    --asset-dir model-tests",
      "",
    ].join("\n")
  );
}

function parseArgs(argv) {
  const args = {
    backupRoot: DEFAULT_BACKUP_ROOT,
    source: "",
    dest: "",
    assetDir: "",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (arg === "--source") {
      args.source = next || "";
      i += 1;
    } else if (arg === "--dest") {
      args.dest = next || "";
      i += 1;
    } else if (arg === "--asset-dir") {
      args.assetDir = next || "";
      i += 1;
    } else if (arg === "--backup-root") {
      args.backupRoot = next || "";
      i += 1;
    } else if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    }
  }

  if (!args.source || !args.dest || !args.assetDir) {
    usage();
    process.exit(1);
  }

  return args;
}

function fileExists(p) {
  return fssync.existsSync(p);
}

function sanitizeFilename(name, fallbackSeed) {
  const parsed = path.parse(name);
  const ext = (parsed.ext || "").toLowerCase();
  const stem = (parsed.name || "image")
    .normalize("NFKD")
    .replace(/[^\x00-\x7F]/g, "")
    .replace(/[+\s]+/g, "-")
    .replace(/[^A-Za-z0-9._-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-+|-+$/g, "");
  const safeStem = stem || `image-${fallbackSeed}`;
  const safeExt = ext || ".jpg";
  return `${safeStem}${safeExt}`;
}

function canonicalizeSqspFilename(name) {
  let out = String(name || "");
  out = out.replace(/\uFE16/g, "?");
  out = out.replace(/[?﹖].*$/g, "");

  // Normalize common Squarespace variant encodings to a single master filename.
  out = out.replace(/-content-type(?:=|-)?image[-/]?[A-Za-z0-9.+-]+/gi, "");
  out = out.replace(/-content-type-image[a-z0-9]+/gi, "");
  out = out.replace(/\.(jpe?g|png|gif)\.webp$/i, ".$1");
  out = out.replace(/\.(jpe?g|png|gif)-format-\d+w\.(jpe?g|png|gif|webp)$/i, ".$1");
  out = out.replace(/-format-\d+w\.(jpe?g|png|gif|webp)$/i, ".$1");

  return out;
}

function normalizeImageRef(ref) {
  let value = String(ref || "").trim();
  if (!value) return "";
  value = value
    .replace(/&amp;/gi, "&")
    .replace(/&apos;|&#39;/gi, "'")
    .replace(/&quot;/gi, '"');

  if (value.startsWith("http://") || value.startsWith("https://")) {
    try {
      const u = new URL(value);
      return `${u.pathname}${u.search}`;
    } catch {
      return "";
    }
  }

  if (value.startsWith("//")) {
    try {
      const u = new URL(`https:${value}`);
      return `${u.pathname}${u.search}`;
    } catch {
      return "";
    }
  }

  if (value.startsWith("/")) return value;

  // Collapse relative refs (../ or ../../) into site-root refs.
  value = value.replace(/^(\.\.\/)+/g, "");
  if (!value.startsWith("/")) value = `/${value}`;
  return value;
}

function decodePath(p) {
  let out = p;
  try {
    out = decodeURIComponent(out);
  } catch {
    try {
      out = decodeURI(out);
    } catch {
      // leave as-is
    }
  }
  return out.replace(/\uFE16/g, "﹖");
}

function toLocalFsPath(backupRoot, urlPath) {
  const trimmed = urlPath.replace(/^\/+/, "");
  return path.join(backupRoot, trimmed);
}

function deriveMasterUrlPath(decodedUrlPath) {
  const dir = path.posix.dirname(decodedUrlPath);
  const name = path.posix.basename(decodedUrlPath);
  const idx = Math.max(name.indexOf("﹖"), name.indexOf("?"));
  if (idx === -1) return decodedUrlPath;

  const prefix = name.slice(0, idx);
  const suffix = name.slice(idx + 1);
  const suffixExt = path.posix.extname(suffix);
  const hasExt = Boolean(path.posix.extname(prefix));
  const masterName = hasExt ? prefix : `${prefix}${suffixExt}`;
  return path.posix.join(dir, masterName);
}

function extractRefs(html) {
  const refs = new Set();

  const attrRegex = /(?:src|href|data-src|data-image|poster)\s*=\s*["']([^"']+)["']/gi;
  let match;
  while ((match = attrRegex.exec(html)) !== null) {
    refs.add(match[1]);
  }

  const srcsetRegex = /srcset\s*=\s*["']([^"']+)["']/gi;
  while ((match = srcsetRegex.exec(html)) !== null) {
    const parts = match[1].split(",");
    for (const part of parts) {
      const candidate = part.trim().replace(/\s+\d+(?:w|x)$/i, "");
      if (candidate) refs.add(candidate);
    }
  }

  const inlineImageRegex =
    /(?:https?:)?\/\/images\.squarespace-cdn\.com\/[^\s"'<>]+|\/images\.squarespace-cdn\.com\/[^\s"'<>]+|(?:\.\.\/)+images\.squarespace-cdn\.com\/[^\s"'<>]+/gi;
  while ((match = inlineImageRegex.exec(html)) !== null) {
    refs.add(match[0]);
  }

  return Array.from(refs);
}

function stripPlausibleAndTracking(html) {
  let out = html;
  out = out.replace(
    /<!--\s*Privacy-friendly analytics by Plausible\s*-->[\s\S]*?<\/script>\s*<script>[\s\S]*?<\/script>\s*<script>[\s\S]*?<\/script>/gi,
    ""
  );
  out = out.replace(/<script[^>]*src=["'][^"']*plausible[^"']*["'][^>]*>\s*<\/script>/gi, "");
  out = out.replace(/<script>[\s\S]*?window\.plausible[\s\S]*?<\/script>/gi, "");
  out = out.replace(/<script>[\s\S]*?model-contact-click[\s\S]*?<\/script>/gi, "");
  return out;
}

function stripContentShooterNav(html) {
  return html.replace(/<li[^>]*>\s*<a[^>]*content-shoots[^<]*<\/a>\s*<\/li>/gi, "");
}

function stripImageCdnPreconnect(html) {
  return html.replace(
    /<link\b[^>]*rel=["']preconnect["'][^>]*href=["'][^"']*images\.squarespace-cdn\.com[^"']*["'][^>]*>\s*/gi,
    ""
  );
}

function rewriteRelativePrefixes(html) {
  // Convert ../ and ../../ asset/link refs into root-relative refs for static hosting.
  return html.replace(
    /((?:src|href|poster|data-src|data-image|srcset)\s*=\s*["'])(?:\.\.\/)+/gi,
    "$1/"
  );
}

function rewriteInternalHtmlLinks(html) {
  return html.replace(/href=(["'])([^"']+)\1/gi, (full, quote, rawHref) => {
    let href = rawHref.trim();
    if (!href) return full;
    if (/^(https?:|\/\/|mailto:|tel:|javascript:|#)/i.test(href)) return full;
    if (!/\.html(?:[?#]|$)/i.test(href)) return full;

    const hashIndex = href.indexOf("#");
    const queryIndex = href.indexOf("?");
    let splitIndex = -1;
    if (hashIndex !== -1 && queryIndex !== -1) splitIndex = Math.min(hashIndex, queryIndex);
    else splitIndex = Math.max(hashIndex, queryIndex);

    const pathPart = splitIndex === -1 ? href : href.slice(0, splitIndex);
    const suffix = splitIndex === -1 ? "" : href.slice(splitIndex);
    if (!pathPart.toLowerCase().endsWith(".html")) return full;

    let next = pathPart.slice(0, -5); // drop .html
    if (!next || next === "index" || next === "/index") {
      next = "/";
    } else {
      if (!next.startsWith("/")) next = `/${next}`;
      next = next.replace(/\/+/g, "/");
      if (!next.endsWith("/")) next = `${next}/`;
    }
    return `href=${quote}${next}${suffix}${quote}`;
  });
}

function routePathFromDest(dest) {
  let value = String(dest || "").replace(/\\/g, "/").trim();
  if (!value) return "/";
  if (value.toLowerCase().endsWith("/index.html")) {
    value = value.slice(0, -"/index.html".length);
  } else if (value.toLowerCase().endsWith(".html")) {
    value = value.slice(0, -".html".length);
  }
  value = value.replace(/^\.?\/*/, "");
  if (value.toLowerCase() === "index") return "/";
  if (!value) return "/";
  return `/${value}/`;
}

function rewriteCanonicalHref(html, routePath) {
  const canonicalTagRegex = /<link\b[^>]*rel=["']canonical["'][^>]*>/i;
  if (canonicalTagRegex.test(html)) {
    return html.replace(canonicalTagRegex, `<link rel="canonical" href="${routePath}">`);
  }
  return html.replace(/<\/head>/i, `  <link rel="canonical" href="${routePath}">\n</head>`);
}

function injectCensusDisableFlag(html) {
  if (html.includes("__WE_ARE_SQUARESPACE_DISABLING_CENSUS__")) return html;
  return html.replace(
    /<head>/i,
    "<head>\n<script>window.__WE_ARE_SQUARESPACE_DISABLING_CENSUS__ = true;</script>"
  );
}

function injectLocalDevNoiseGuard(html) {
  if (html.includes("__DB_LOCAL_DEV_NOISE_GUARD__")) return html;
  const guardScript = [
    "<script>",
    "(function () {",
    "  var isLocal = /^(localhost|127\\.0\\.0\\.1)$/.test(window.location.hostname);",
    "  if (!isLocal) return;",
    "  window.__DB_LOCAL_DEV_NOISE_GUARD__ = true;",
    "",
    "  function scrubVimeoUrl(value) {",
    "    if (typeof value !== 'string') return value;",
    "    return value.replace(/https?:\\/\\/player\\.vimeo\\.com\\/video\\/[^\\\"'\\s>]+/gi, 'about:blank');",
    "  }",
    "",
    "  // Block any late Typekit script injection while preserving layout class cleanup.",
    "  var originalAppendChild = Node.prototype.appendChild;",
    "  Node.prototype.appendChild = function (node) {",
    "    try {",
    "      if (node && node.tagName === 'SCRIPT') {",
    "        var src = (node.getAttribute && node.getAttribute('src')) || node.src || '';",
    "        if (/use\\.typekit\\.net\\/ik\\//i.test(String(src))) {",
    "          document.documentElement.classList.remove('wf-loading');",
    "          return node;",
    "        }",
    "      }",
    "    } catch (e) {}",
    "    return originalAppendChild.call(this, node);",
    "  };",
    "",
    "  // Prevent runtime components from re-injecting Vimeo embed URLs into data-html.",
    "  var originalSetAttribute = Element.prototype.setAttribute;",
    "  Element.prototype.setAttribute = function (name, value) {",
    "    if (this && this.classList && this.classList.contains('sqs-video-wrapper') && String(name).toLowerCase() === 'data-html') {",
    "      return originalSetAttribute.call(this, name, scrubVimeoUrl(value));",
    "    }",
    "    return originalSetAttribute.call(this, name, value);",
    "  };",
    "",
    "  function scrubVimeoDataHtml(root) {",
    "    if (!root || !root.querySelectorAll) return;",
    "    root.querySelectorAll('.sqs-video-wrapper[data-html*=\"player.vimeo.com/video/\"]').forEach(function (el) {",
    "      var raw = el.getAttribute('data-html') || '';",
    "      var next = scrubVimeoUrl(raw);",
    "      if (next !== raw) el.setAttribute('data-html', next);",
    "    });",
    "  }",
    "",
    "  function suppressVimeoPreviewIframes(root) {",
    "    if (!root || !root.querySelectorAll) return;",
    "    root.querySelectorAll('iframe[src*=\"player.vimeo.com/video/\"]').forEach(function (iframe) {",
    "      if (iframe.dataset && iframe.dataset.dbLocalSrcSuppressed) return;",
    "      if (iframe.dataset) iframe.dataset.dbLocalSrcSuppressed = iframe.getAttribute('src') || '';",
    "      iframe.setAttribute('src', 'about:blank');",
    "    });",
    "  }",
    "",
    "  if (document.readyState === 'loading') {",
    "    document.addEventListener('DOMContentLoaded', function () {",
    "      scrubVimeoDataHtml(document);",
    "      suppressVimeoPreviewIframes(document);",
    "    }, { once: true });",
    "  } else {",
    "    scrubVimeoDataHtml(document);",
    "    suppressVimeoPreviewIframes(document);",
    "  }",
    "",
    "  var observer = new MutationObserver(function (mutations) {",
    "    for (var i = 0; i < mutations.length; i += 1) {",
    "      var mutation = mutations[i];",
    "      for (var j = 0; j < mutation.addedNodes.length; j += 1) {",
    "        scrubVimeoDataHtml(mutation.addedNodes[j]);",
    "        suppressVimeoPreviewIframes(mutation.addedNodes[j]);",
    "      }",
    "      if (mutation.type === 'attributes' && mutation.target && mutation.target.matches && mutation.target.matches('.sqs-video-wrapper[data-html*=\"player.vimeo.com/video/\"]')) {",
    "        scrubVimeoDataHtml(mutation.target.parentNode || document);",
    "      }",
    "      if (mutation.type === 'attributes' && mutation.target && mutation.target.matches && mutation.target.matches('iframe[src*=\"player.vimeo.com/video/\"]')) {",
    "        suppressVimeoPreviewIframes(mutation.target.parentNode || document);",
    "      }",
    "    }",
    "  });",
    "",
    "  observer.observe(document.documentElement, {",
    "    childList: true,",
    "    subtree: true,",
    "    attributes: true,",
    "    attributeFilter: ['src', 'data-html'],",
    "  });",
    "})();",
    "</script>",
  ].join("\n");

  return html.replace(/<head>/i, `<head>\n${guardScript}`);
}

function rewriteTypekitScriptTag(html) {
  const typekitTagRegex =
    /<script\b[^>]*\bsrc=(["'])([^"']*\/use\.typekit\.net\/ik\/[^"']+)\1[^>]*><\/script>/i;

  return html.replace(typekitTagRegex, (_full, _quote, src) => {
    const srcLiteral = JSON.stringify(src);
    return [
      "<script>",
      "(function () {",
      "  var isLocal = /^(localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0|::1)$/.test(location.hostname);",
      "  if (isLocal) {",
      "    window.Typekit = window.Typekit || { load: function () {} };",
      "    document.documentElement.classList.remove('wf-loading');",
      "    return;",
      "  }",
      "  var s = document.createElement('script');",
      `  s.src = ${srcLiteral};`,
      "  s.async = true;",
      "  s.setAttribute('fetchpriority', 'high');",
      "  s.onload = function () {",
      "    try { Typekit.load(); } catch (e) {}",
      "    document.documentElement.classList.remove('wf-loading');",
      "  };",
      "  document.head.appendChild(s);",
      "})();",
      "</script>",
    ].join("\n");
  });
}

function hardenTypekitOnload(html) {
  const legacy =
    "onload=\"try{Typekit.load();}catch(e){} document.documentElement.classList.remove('wf-loading');\"";
  const hardened =
    "onload=\"if(!/^(localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0|::1)$/.test(location.hostname)){try{Typekit.load();}catch(e){}} document.documentElement.classList.remove('wf-loading');\"";
  return html.replaceAll(legacy, hardened);
}

function hardenSquarespaceBlockAttrs(html) {
  let out = html;
  out = out.replace(/\sdata-block-scripts="[^"]*"/g, "");
  out = out.replace(/\sallowfullscreen(?=\s|>)/g, "");
  return out;
}

function normalizeImageQueryPart(rawQuery) {
  if (!rawQuery) return "";
  let query = String(rawQuery)
    .replace(/&amp;/gi, "&")
    .replace(/\uFE16/g, "?")
    .trim()
    .replace(/^[?&]+/, "");
  if (!query) return "";

  const parts = query.split("&").map((part) => part.trim()).filter(Boolean);
  const normalized = [];

  for (const part of parts) {
    if (/^content-type=/i.test(part)) {
      continue;
    }

    const formatMatch = part.match(
      /^format=(\d{3,}w|original)(?:\.(?:jpe?g|png|webp|gif|avif|ico))?$/i
    );
    if (formatMatch) {
      normalized.push(`format=${formatMatch[1].toLowerCase()}`);
      continue;
    }

    const looseFormatMatch = part.match(/^format=(\d{3,}w|original)/i);
    if (looseFormatMatch) {
      normalized.push(`format=${looseFormatMatch[1].toLowerCase()}`);
      continue;
    }

    normalized.push(part);
  }

  return normalized.join("&");
}

async function localizeImageRefs({ html, backupRoot, repoRoot, assetDir }) {
  const refs = extractRefs(html).filter((ref) => /images\.squarespace-cdn\.com/i.test(ref));
  const uniqueRefs = Array.from(new Set(refs));
  const replacements = new Map();
  const copied = [];
  const unresolved = [];
  const usedNames = new Map();

  for (const rawRef of uniqueRefs) {
    const normRef = normalizeImageRef(rawRef);
    if (!normRef.includes("images.squarespace-cdn.com")) continue;
    const decodedRef = decodePath(normRef);
    const masterRef = deriveMasterUrlPath(decodedRef);

    const masterFs = toLocalFsPath(backupRoot, masterRef);
    const decodedFs = toLocalFsPath(backupRoot, decodedRef);
    let sourceFs = "";
    let sourceRef = "";

    if (fileExists(masterFs)) {
      sourceFs = masterFs;
      sourceRef = masterRef;
    } else if (fileExists(decodedFs)) {
      sourceFs = decodedFs;
      sourceRef = decodedRef;
    }

    if (!sourceFs) {
      unresolved.push(rawRef);
      continue;
    }

    const seed = crypto.createHash("sha1").update(sourceRef).digest("hex").slice(0, 8);
    const rawName = canonicalizeSqspFilename(path.basename(sourceRef));
    let filename = sanitizeFilename(rawName, seed);
    const existingSource = usedNames.get(filename);
    if (existingSource && existingSource !== sourceRef) {
      const parsed = path.parse(filename);
      filename = `${parsed.name}--${seed}${parsed.ext}`;
    }
    usedNames.set(filename, sourceRef);

    const relOut = `/assets/images/pages/${assetDir}/${filename}`.replace(/\/+/g, "/");
    const queryIdx = Math.max(decodedRef.indexOf("?"), decodedRef.indexOf("﹖"));
    const queryPartRaw =
      queryIdx !== -1 && queryIdx + 1 < decodedRef.length
        ? decodedRef.slice(queryIdx + 1).trim()
        : "";
    const queryPart = normalizeImageQueryPart(queryPartRaw);
    const localizedRef = queryPart ? `${relOut}?${queryPart}` : `${relOut}?format=1500w`;
    const absOut = path.join(repoRoot, relOut.slice(1));
    await fs.mkdir(path.dirname(absOut), { recursive: true });
    if (!fileExists(absOut)) {
      await fs.copyFile(sourceFs, absOut);
      copied.push(relOut);
    }

    replacements.set(rawRef, localizedRef);
  }

  let outHtml = html;
  const refsByLength = Array.from(replacements.keys()).sort((a, b) => b.length - a.length);
  for (const rawRef of refsByLength) {
    const target = replacements.get(rawRef);
    outHtml = outHtml.split(rawRef).join(target);
  }

  return {
    html: outHtml,
    copiedCount: copied.length,
    rewrittenCount: replacements.size,
    unresolved,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const sourceAbs = path.isAbsolute(args.source) ? args.source : path.join(repoRoot, args.source);
  const destAbs = path.isAbsolute(args.dest) ? args.dest : path.join(repoRoot, args.dest);

  if (!fileExists(sourceAbs)) {
    throw new Error(`Source file not found: ${sourceAbs}`);
  }
  if (!fileExists(args.backupRoot)) {
    throw new Error(`Backup root not found: ${args.backupRoot}`);
  }

  let html = await fs.readFile(sourceAbs, "utf8");
  html = rewriteRelativePrefixes(html);
  html = rewriteInternalHtmlLinks(html);
  html = rewriteCanonicalHref(html, routePathFromDest(args.dest));
  html = stripImageCdnPreconnect(html);
  html = stripPlausibleAndTracking(html);
  html = stripContentShooterNav(html);
  html = hardenSquarespaceBlockAttrs(html);
  html = rewriteTypekitScriptTag(html);
  html = hardenTypekitOnload(html);
  html = injectCensusDisableFlag(html);

  const localized = await localizeImageRefs({
    html,
    backupRoot: args.backupRoot,
    repoRoot,
    assetDir: args.assetDir.replace(/^\/+|\/+$/g, ""),
  });
  html = localized.html;

  await fs.mkdir(path.dirname(destAbs), { recursive: true });
  await fs.writeFile(destAbs, html, "utf8");

  const unresolvedCount = localized.unresolved.length;
  process.stdout.write(`Wrote page: ${destAbs}\n`);
  process.stdout.write(`Image refs rewritten: ${localized.rewrittenCount}\n`);
  process.stdout.write(`Images copied: ${localized.copiedCount}\n`);
  process.stdout.write(`Unresolved image refs: ${unresolvedCount}\n`);
  if (unresolvedCount) {
    const sample = localized.unresolved.slice(0, 12);
    for (const ref of sample) {
      process.stdout.write(`  - ${ref}\n`);
    }
  }
}

main().catch((error) => {
  process.stderr.write(`${String(error?.stack || error)}\n`);
  process.exit(1);
});
