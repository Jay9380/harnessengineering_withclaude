#!/bin/bash
# 배치 '변환' 흉내: 1~3초 걸리는 작업 후 work.log에 "<배치> <워커>" 한 줄을 남긴다.
cd "$(dirname "$0")"; sleep $((RANDOM % 3 + 1)); echo "$1 $2" >> work.log
