#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-/Users/daveblake/site-backups/dave-blake-sspro/dave-blake.com}"
OUTPUT_DIR="${2:-data/migration/phase0}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

ALL_FILES="$OUTPUT_DIR/all_files.txt"
LEGACY_URLS="$OUTPUT_DIR/legacy_urls.txt"
URL_CLASSES="$OUTPUT_DIR/url_classes.csv"
SUMMARY="$OUTPUT_DIR/summary.txt"

find "$SOURCE_DIR" -type f | sed "s|^$SOURCE_DIR/|/|" | sort > "$ALL_FILES"

find "$SOURCE_DIR" -type f \( -name "*.html" -o -name "*.rss" \) \
  | sed "s|^$SOURCE_DIR||" \
  | sed "s|/index\\.html$|/|g" \
  | sort > "$LEGACY_URLS"

awk '
BEGIN {
  print "url,class";
}
{
  url=$0;
  cls="page";

  if (url ~ /\.rss$/) cls="rss";
  else if (url ~ /\/tag\//) cls="tag";
  else if (url ~ /\/category\//) cls="category";
  else if (url ~ /﹖/) cls="query_variant";
  else if (url ~ /\/story\/[0-9]{4}\//) cls="dated_story";
  else if (url ~ /\/photographer\/[0-9]{4}\//) cls="dated_photographer";
  else if (url ~ /\/story\/.*\.html$/) cls="story_article";
  else if (url ~ /\/blog\/.*\.html$/) cls="blog_article";

  print url "," cls;
}
' "$LEGACY_URLS" > "$URL_CLASSES"

total_urls=$(wc -l < "$LEGACY_URLS" | tr -d " ")
tag_urls=$(awk -F, 'NR>1 && $2=="tag"{c++} END{print c+0}' "$URL_CLASSES")
category_urls=$(awk -F, 'NR>1 && $2=="category"{c++} END{print c+0}' "$URL_CLASSES")
query_variants=$(awk -F, 'NR>1 && $2=="query_variant"{c++} END{print c+0}' "$URL_CLASSES")
dated_story=$(awk -F, 'NR>1 && $2=="dated_story"{c++} END{print c+0}' "$URL_CLASSES")
dated_photographer=$(awk -F, 'NR>1 && $2=="dated_photographer"{c++} END{print c+0}' "$URL_CLASSES")
story_articles=$(awk -F, 'NR>1 && $2=="story_article"{c++} END{print c+0}' "$URL_CLASSES")
blog_articles=$(awk -F, 'NR>1 && $2=="blog_article"{c++} END{print c+0}' "$URL_CLASSES")
rss_urls=$(awk -F, 'NR>1 && $2=="rss"{c++} END{print c+0}' "$URL_CLASSES")

{
  echo "source_dir=$SOURCE_DIR"
  echo "generated_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "total_urls=$total_urls"
  echo "tag_urls=$tag_urls"
  echo "category_urls=$category_urls"
  echo "query_variants=$query_variants"
  echo "dated_story_urls=$dated_story"
  echo "dated_photographer_urls=$dated_photographer"
  echo "story_article_urls=$story_articles"
  echo "blog_article_urls=$blog_articles"
  echo "rss_urls=$rss_urls"
} > "$SUMMARY"

echo "Phase 0 inventory complete."
echo "Output directory: $OUTPUT_DIR"
echo "Summary:"
cat "$SUMMARY"
