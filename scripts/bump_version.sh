#!/bin/bash
# 自动更新 mobile/pubspec.yaml 的 build number
# 用法: ./scripts/bump_version.sh [mobile|desktop|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TARGET="${1:-mobile}"

bump_build_number() {
  local pubspec_path="$1"
  if [ ! -f "$pubspec_path" ]; then
    echo "错误: 找不到 $pubspec_path"
    return 1
  fi

  # 读取当前版本号，例如 version: 1.0.0+5
  local current_line
  current_line=$(grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+' "$pubspec_path" || true)

  if [ -z "$current_line" ]; then
    echo "错误: 在 $pubspec_path 中找不到版本号"
    return 1
  fi

  # 解析版本号和 build number
  local version_part
  local build_number

  if echo "$current_line" | grep -q '+'; then
    version_part=$(echo "$current_line" | sed -E 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$/\1/')
    build_number=$(echo "$current_line" | sed -E 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$/\2/')
    build_number=$((build_number + 1))
  else
    version_part=$(echo "$current_line" | sed -E 's/^version: ([0-9]+\.[0-9]+\.[0-9]+).*$/\1/')
    build_number=1
  fi

  local new_version="$version_part+$build_number"

  # 替换版本号
  sed -i "s/^version: .*/version: $new_version/" "$pubspec_path"

  echo "✅ 已更新 $(basename "$(dirname "$pubspec_path")") 版本号: $new_version"
}

if [ "$TARGET" = "mobile" ] || [ "$TARGET" = "all" ]; then
  bump_build_number "$PROJECT_ROOT/mobile/pubspec.yaml"
fi

if [ "$TARGET" = "desktop" ] || [ "$TARGET" = "all" ]; then
  bump_build_number "$PROJECT_ROOT/desktop/pubspec.yaml"
fi

if [ "$TARGET" = "common" ] || [ "$TARGET" = "all" ]; then
  bump_build_number "$PROJECT_ROOT/common/pubspec.yaml"
fi

echo "完成!"
