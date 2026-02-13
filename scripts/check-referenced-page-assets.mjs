#!/usr/bin/env node

import { execFileSync } from "node:child_process";

function parseArgs(argv) {
  let ref = "";
  const files = [];

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--ref") {
      ref = argv[i + 1] || "";
      i += 1;
      continue;
    }
    files.push(arg);
  }

  return { ref, files };
}

function git(args, allowFailure = false) {
  try {
    return execFileSync("git", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    if (allowFailure) return null;
    throw error;
  }
}

function getFileAtRef(ref, filePath) {
  return git(["show", `${ref}:${filePath}`], true);
}

function assetExistsAtRef(ref, assetRelPath) {
  const result = git(["cat-file", "-e", `${ref}:${assetRelPath}`], true);
  return result !== null;
}

function extractPageAssetPaths(content) {
  const results = new Set();
  const regex = /\/assets\/images\/pages\/[^\s"'<>`)]*/gi;
  let match;

  while ((match = regex.exec(content)) !== null) {
    const raw = String(match[0] || "");
    if (!raw) continue;

    const deEntitized = raw.replace(/&amp;/gi, "&");
    const trimmed = deEntitized.replace(/[),.;]+$/g, "");
    const noFragment = trimmed.split("#")[0];
    const noQuery = noFragment.split("?")[0];

    if (!noQuery.startsWith("/assets/images/pages/")) continue;

    const relPath = noQuery.slice(1);
    if (!relPath || relPath.includes("..")) continue;

    results.add(relPath);
  }

  return Array.from(results).sort();
}

function main() {
  const { ref, files } = parseArgs(process.argv.slice(2));

  if (!ref) {
    process.stderr.write("Missing required --ref <commit-ish> argument.\n");
    process.exit(2);
  }

  if (!files.length) process.exit(0);

  const issues = [];

  for (const filePath of files) {
    const content = getFileAtRef(ref, filePath);
    if (content === null) continue;

    const assets = extractPageAssetPaths(content);
    for (const assetRelPath of assets) {
      if (!assetExistsAtRef(ref, assetRelPath)) {
        issues.push({
          filePath,
          assetPath: `/${assetRelPath}`,
        });
      }
    }
  }

  if (!issues.length) {
    process.exit(0);
  }

  process.stderr.write(
    `Missing page assets in pushed commit (${ref}) for changed HTML files:\n`
  );

  for (const issue of issues) {
    process.stderr.write(` - ${issue.filePath} -> ${issue.assetPath}\n`);
  }

  process.stderr.write(
    "\nFix: add missing files to git, commit, and push again.\n"
  );
  process.exit(1);
}

main();

