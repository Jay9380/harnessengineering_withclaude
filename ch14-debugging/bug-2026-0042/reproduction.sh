#!/usr/bin/env bash
# Bug: 2026-0042 — "data.failedIndices is undefined" (주문 배너가 크래시)
# Expected: exit 1 before fix, exit 0 after fix
set -euo pipefail
cd "$(dirname "$0")"
out=$(node -e 'const {submitOrders}=require("./src/ui"); console.log(submitOrders([{qty:1},{qty:0},{qty:0}]))' 2>&1) || {
  echo "BUG REPRODUCED: crash — $out"; exit 1; }
[ "$out" = "2건의 주문이 실패했습니다" ] || { echo "BUG REPRODUCED: wrong banner — '$out'"; exit 1; }
echo "BUG NOT REPRODUCED"; exit 0
