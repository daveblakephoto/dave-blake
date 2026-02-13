# Phase 0 Kickoff

## Goal
Create the baseline datasets required for a safe migration:
- URL inventory
- URL class distribution
- Redirect matrix seed
- Benchmark placeholders for Search Console exports

## 1) Generate URL Inventory
Run:

```bash
bash scripts/phase0_inventory.sh
```

Or with custom paths:

```bash
bash scripts/phase0_inventory.sh /Users/daveblake/site-backups/dave-blake-sspro/dave-blake.com data/migration/phase0
```

## 2) Export Search Console Benchmarks
Preferred (scripted):

```bash
bash scripts/bootstrap_gsc_oauth.sh /absolute/path/to/client_secret_desktop.json
GSC_OAUTH_FILE="$HOME/.config/dave-blake/gsc_oauth.json" bash scripts/phase0_gsc_and_redirect_seed.sh
```

Or if your token is already in an env var:

```bash
GSC_BEARER_TOKEN="YOUR_TOKEN" bash scripts/phase0_gsc_and_redirect_seed.sh
```

Combined command (if token already configured in env/file):

```bash
bash scripts/phase0_gsc_and_redirect_seed.sh
```

Notes:
- A Google OAuth **Client ID** is not an API bearer token.
- If you only have the Client ID (as shown in Google Cloud), run `bootstrap_gsc_oauth.sh` first.
- Default behavior skips legacy site export (`GSC_SKIP_LEGACY=1`), which is appropriate when `.com.au` is redirect-only and has no useful performance data.

Token config options:
- `GSC_BEARER_TOKEN`
- `GSC_BEARER_TOKEN_FILE`

The script exports both properties:
- `https://dave-blake.com/`
- `https://daveblake.com.au/`

Recommended windows:
- Last 90 days
- Same 90-day window previous year

Save exports to:
- `data/migration/phase0/gsc_*_pages_last90.csv`
- `data/migration/phase0/gsc_*_queries_last90.csv`
- `data/migration/phase0/gsc_*_page_query_last90.csv`
- `data/migration/phase0/gsc_*_pages_prevyear90.csv`
- `data/migration/phase0/gsc_*_queries_prevyear90.csv`
- `data/migration/phase0/gsc_*_page_query_prevyear90.csv`

## 3) Build Redirect Matrix (Seed)
Start with:
- `data/migration/phase0/legacy_urls.txt`

Generate:

```bash
bash scripts/seed_redirect_matrix.sh
```

Output:
- `data/migration/phase0/redirect_matrix_seed.csv`
- `data/migration/phase0/redirect_priority_p0_p1.csv`
- `data/migration/phase0/backlink_targets.txt` (input file to boost priority for known linked legacy URLs)

CSV columns:
- `legacy_url`
- `target_url`
- `status_code`
- `priority`
- `reason`
- `confidence`
- `last90_clicks`
- `backlink_flag`
- `notes`

## 4) Exit Criteria
- `legacy_urls.txt` exists and is complete.
- URL classes and duplicates are quantified.
- Redirect matrix exists with at least all high-value URLs mapped.
- GSC benchmark files are stored for pre/post comparison.
- Phase 1 queue artifacts are generated:
  - `gsc_pages_inventory_audit.csv`
  - `gsc_pages_missing_from_inventory.csv`
  - `page_migration_queue.csv`

## 5) Asset Policy
- Use page-level manifests only; do not bulk import the full Squarespace backup.
- See: `docs/migration/page-by-page-assets.md`

## 6) Build Queue
```bash
bash scripts/build_phase1_queue.sh data/migration/phase0
bash scripts/build_page_asset_manifests_from_queue.sh data/migration/phase0 10
```
