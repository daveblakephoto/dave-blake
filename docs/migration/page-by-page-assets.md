# Page-By-Page Asset Strategy

## Rule
Do not import the full Squarespace media mirror into the repo.

## Why
- Keeps Git history and clone size manageable.
- Avoids carrying unused legacy assets.
- Forces asset decisions to follow page migration priority.

## Workflow
1. Generate a per-page asset manifest:
   ```bash
   bash scripts/page_asset_manifest.sh /story/barungas-next-top-model-2025
   ```
   Or from migration queue (top N):
   ```bash
   bash scripts/build_page_asset_manifests_from_queue.sh data/migration/phase0 10
   ```
2. Review:
   - `data/migration/page-assets/<page-slug>/asset_manifest_existing.tsv`
   - `data/migration/page-assets/<page-slug>/asset_manifest_missing.tsv`
3. Select only assets needed for the migrated page.
4. Import/optimize selected assets for that page only.
5. Repeat for each page in migration order.

## Image Naming
- Prefer human-readable filenames from the original asset name (for example `DaveBlake_NYFW-OliviaVinten-001.jpg`).
- Drop Squarespace storage prefixes like `1692800565206-06Y...--` from repo filenames.
- Keep names stable once published to avoid churn in image indexing and social cache targets.
- Store page images under `assets/images/pages/<page-slug>/`.

## Variant Policy
- Keep one master image per visual asset in git.
- Do not keep Squarespace derivative variants like `-format-750w`, `-format-1500w`, `-format-2500w`.
- Use the largest available source variant as the master (unless quality/compression regression is found).

## Output Paths
- Manifest root: `data/migration/page-assets/`
- Baseline migration data: `data/migration/phase0/`

## Guardrails
- Never do bulk copy from `/Users/daveblake/site-backups/dave-blake-sspro`.
- Every imported asset should trace back to a page manifest.
- Keep old and new asset URLs mappable during transition to avoid broken media.

## Cloudflare Delivery
- Use Cloudflare for optimization and responsive delivery, not git-stored duplicate sizes.
- Keep the canonical image URL as the clean origin path (for example `/assets/images/pages/home/DaveBlake_NYFW-OliviaVinten-001.jpg`).
- Serve responsive variants via Cloudflare Image Resizing (`/cdn-cgi/image/...`) in `srcset`.
- Keep `src` on the canonical clean path to stabilize image indexing while `srcset` handles performance.
