#!/usr/bin/env bash
# Blender 백그라운드 실행기: bash roblox/tools/blender/bl.sh <스크립트.py> [인자...]
# 허용 목록 규칙 하나(Bash(bash roblox/tools/blender/bl.sh:*))로 모든 빌드 · 렌더를 덮기 위한 얇은 래퍼.
script="$1"; shift
exec "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P "$script" -- "$@"
