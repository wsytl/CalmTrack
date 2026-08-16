#!/usr/bin/env bash
# CalmTrack 一键打包脚本（包装 fastlane ios package）
#
# 用法：
#   ./scripts/package.sh                                # development 环境，build 号自动 +1
#   ./scripts/package.sh --env appstore                 # App Store 签名（需已配置 API key + match）
#   ./scripts/package.sh --version 1.2.0                # 指定版本号（覆盖 MARKETING_VERSION，仅本次生效）
#   ./scripts/package.sh --env appstore --version 1.2.0 # 组合
#
# 参数：
#   --env development|appstore   打包环境（默认 development）
#                                development = Development 签名（本机 Automatic signing，装到已登记设备）
#                                appstore    = App Store 签名（Distribution 证书，经 match 管理；未配置会报错）
#   --version x.y.z              版本号（可选；不传保持工程当前 MARKETING_VERSION）
#   --help | -h                  显示本帮助
#
# 说明：
#   - build 号（CURRENT_PROJECT_VERSION）每次打包自动 +1 并写回工程文件，请随改动一起提交。
#   - 产物：build/ipa/CalmTrack-<env>[-<version>]-<build>.ipa
set -euo pipefail

ENV_NAME="development"
VERSION=""

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || { echo "错误：--env 需要一个参数" >&2; exit 1; }
      ENV_NAME="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || { echo "错误：--version 需要一个参数" >&2; exit 1; }
      VERSION="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "错误：未知参数 '$1'（--help 查看用法）" >&2
      exit 1
      ;;
  esac
done

case "$ENV_NAME" in
  development|appstore) ;;
  *) echo "错误：--env 必须是 development 或 appstore，收到 '$ENV_NAME'" >&2; exit 1 ;;
esac

# 切到仓库根（脚本位于 scripts/ 下）
cd "$(cd "$(dirname "$0")" && pwd)/.."

if ! command -v fastlane >/dev/null 2>&1; then
  echo "错误：未找到 fastlane，请先安装：brew install fastlane" >&2
  exit 1
fi

ARGS=(ios package env:"$ENV_NAME")
if [[ -n "$VERSION" ]]; then
  ARGS+=(version:"$VERSION")
fi

echo "==> CalmTrack 打包：env=${ENV_NAME}${VERSION:+  version=${VERSION}}（build 号自动递增）"
echo "==> 命令：fastlane ${ARGS[*]}"
fastlane "${ARGS[@]}"
