# Local QA Workflow (Durable)

Use this loop before pushing to `main` so deploy is only final verification.

## 1) Run strict local preflight

```bash
npm run qa:local:strict
```

What it does:
- Serves the current repo locally on `http://127.0.0.1:4173`
- Runs `dev-vs-prod` strict checks
- Fails if any critical parity issue is found

## 2) Check pages in clean browser profile

```bash
# homepage
bash scripts/open-clean-chrome.sh /

# any route
bash scripts/open-clean-chrome.sh /model-tests/
```

What it does:
- Launches Chrome with extensions disabled
- Uses a dedicated profile at `~/.cache/dave-blake-chrome-clean`
- Reduces extension-noise errors (Zotero/SingleFile/etc.)

## 3) Only then push/deploy

Deploy checks are still required for domain-bound behavior:
- Vimeo domain restrictions
- real HTTPS + CSP behavior
- Cloudflare DNS/redirect/caching behavior
- GitHub Pages runtime differences

Local should catch most structural regressions first; deploy should be confirmation, not discovery.
