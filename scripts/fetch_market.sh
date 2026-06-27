#!/bin/bash
set -euo pipefail

OUTPUT="test/fixtures/gamma/markets.txt"

MARKET_IDS=(
  2691844 2691846 2691850 2691853 2691855 2691856 2691857 2691858
  2691863 2691865 2691868 2691869 2691870 2691871 2691872 2691873
  2691874 2691875 2691876 2691877 2691878 2691879 2691880 2691892
  2691895 2691896 2691897 2691908 2691909 2691910 2691911 2691912
  2691913 2691914 2691915 2691916 2691919 2691920 2691921 2691922
  2691923 2691924 2691925 2691926 2691927 2691928 2691929 2691930
  2691931 2691932
)

fetch_market() {
  local id="$1"
  curl -s "https://gamma-api.polymarket.com/markets/${id}?include_tag=true" >> "test/fixtures/gamma/markets.txt"
  curl -s "https://gamma-api.polymarket.com/markets/${id}/tags" >> "test/fixtures/gamma/tags.txt"
}

: > "test/fixtures/gamma/markets.txt"
: > "test/fixtures/gamma/tags.txt"

for id in "${MARKET_IDS[@]}"; do
  fetch_market "$id"
done
