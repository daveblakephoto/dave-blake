# Next Steps (Current Sprint)

## 1) Review Missing High-Value URLs
File:
- `data/migration/phase0/missing_pages_decisions.tsv`

Why:
- Current GSC data shows URLs with traffic that are not present in the local mirror.
- These must be explicitly recovered or redirected before migration launch.

Action:
- Fill `decision` as one of:
  - `RECOVER_CONTENT`
  - `REDIRECT_TO_EQUIVALENT`
  - `INTENTIONAL_410`

## 2) Lock P0/P1 Redirects
File:
- `data/migration/phase0/redirect_priority_p0_p1.csv`

Action:
- Validate each target.
- Keep single-hop `301` rules only.
- Push first batch to Cloudflare redirect rules/bulk redirects.

## 3) Start Page Migration on Top Queue
Files:
- `data/migration/phase0/page_migration_queue.csv`
- `data/migration/phase0/page_asset_manifest_run.tsv`

Already prepared:
- Asset manifests for first 8 priority pages in `data/migration/page-assets/`.

Action:
- Migrate top pages in queue order.
- Import only assets listed in each page manifest.

## 4) Add Legacy Backlink Targets
File:
- `data/migration/phase0/backlink_targets.txt`

Action:
- Paste known linked legacy URLs from Ahrefs/Semrush/GSC links report.
- Re-run seed to lift their redirect priority.

## 5) Rebuild Queue After Decisions
Commands:
```bash
bash scripts/phase0_gsc_and_redirect_seed.sh data/migration/phase0
bash scripts/build_phase1_queue.sh data/migration/phase0
```

