# SEO-First Migration Plan

## Objective
Migrate from Squarespace to a static GitHub Pages stack while preserving organic rankings, backlink equity, and brand authority.

## Principles
- Preserve URLs first, redesign second.
- No page removals without mapped destination.
- Use permanent (`301`) redirects for all changed URLs.
- Keep `daveblake.com.au` redirects long-term.
- Measure before and after every release.
- Migrate media assets page-by-page; no bulk import of full Squarespace mirror.

## Domain Strategy
- Primary host: `https://www.dave-blake.com`
- Keep apex + `www` configured in GitHub Pages.
- Redirect all `daveblake.com.au/*` to equivalent `www.dave-blake.com/*` paths with `301`.
- Avoid blanket redirects to homepage unless no close equivalent exists.
- Treat `daveblake.com.au` as a legacy redirect-only domain (no dependency on its own GSC performance data).

## Phases
1. Phase 0: Baseline and URL forensics.
2. Phase 1: Static platform foundation (Astro + CI deploy).
3. Phase 2: Redirect and domain infrastructure.
4. Phase 3: SEO-parity content migration.
5. Phase 4: Controlled cutover.
6. Phase 5: Stabilization (4-8 weeks).
7. Phase 6: IA consolidation.
8. Phase 7: SEO growth engine.

## Phase Gates
### Gate A: Baseline complete
- Legacy URL inventory exported.
- Top pages + queries benchmarked from GSC.
- Draft redirect matrix with one-to-one mapping.

### Gate B: Technical parity complete
- Canonicals, robots, sitemap, structured data validated.
- Redirect test pass rate >= 99.5%.
- No multi-hop redirects on mapped URLs.

### Gate C: Launch readiness
- Crawl pass (no critical indexability errors).
- Search Console properties validated and sitemap ready.
- Rollback criteria defined.

### Gate D: Stabilization complete
- No unresolved critical coverage errors.
- Top landing pages recover within expected variance band.

## Deliverables in Repo
- `docs/migration/phase-0-kickoff.md`
- `scripts/phase0_inventory.sh`
- `data/migration/phase0/*`
