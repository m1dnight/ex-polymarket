#!/bin/bash
set -euo pipefail

EVENT_IDS=(
2890 2891 2892 2893 2894 2895 2896 2897 2898 2899
)

fetch_event() {
  local id="$1"
  curl -s "https://gamma-api.polymarket.com/events/${id}?include_chat=true&include_template=true" >> "test/fixtures/gamma/events.txt"
}

: > "test/fixtures/gamma/events.txt"

for id in "${EVENT_IDS[@]}"; do
  fetch_event "$id"
done
