#!/usr/bin/env bash
# CalmTrack 一键打包/分发脚本（包装 fastlane ios package）
#
# 用法：
#   ./scripts/package.sh                                          # development 打包（build +1，不分发）
#   ./scripts/package.sh --env appstore                           # App Store 签名打包（不分发）
#   ./scripts/package.sh --env appstore --distribute testflight --version 1.2.0
#   ./scripts/package.sh --env appstore --distribute appstore --version 1.2.0
#
# 参数：
#   --env development|appstore            签名环境（默认 development）
#                                         development = Development 签名（本机 Automatic，装到已登记设备）
#                                         appstore    = App Store 签名（Distribution 证书，经 match 管理）
#   --distribute none|testflight|appstore 分发目标（默认 none；仅 env=appstore 时可分发）
#                                         none       = 只打包，不上传
#                                         testflight = 打包并上传 TestFlight
#                                         appstore   = 打包并上传 App Store Connect（App 信息/合规需在 ASC 手动确认）
#   --version x.y.z                       版本号（可选；不传保持工程当前 MARKETING_VERSION）
#   --help | -h                           显示本帮助
#
# 说明：
#   - build 号（CURRENT_PROJECT_VERSION）每次打包自动 +1 并写回工程文件，请随改动一起提交。
#   - 产物：build/ipa/CalmTrack-<env>[-<version>]-<build>.ipa
#   - 分发前需先配置 fastlane/.env（App Store Connect API key + match 证书仓库 + match 密码）。
set -euo pipefail

ENV_NAME="development"
DISTRIBUTE="none"
VERSION=""

usage() {
  sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || { echo "错误：--env 需要一个参数" >&2; exit 1; }
      ENV_NAME="$2"
      shift 2
      ;;
    --distribute)
      [[ $# -ge 2 ]] || { echo "错误：--distribute 需要一个参数" >&2; exit 1; }
      DISTRIBUTE="$2"
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
case "$DISTRIBUTE" in
  none|testflight|appstore) ;;
  *) echo "错误：--distribute 必须是 none/testflight/appstore，收到 '$DISTRIBUTE'" >&2; exit 1 ;;
esac
if [[ "$DISTRIBUTE" != "none" && "$ENV_NAME" != "appstore" ]]; then
  echo "错误：--distribute $DISTRIBUTE 需要 --env appstore（App Store 签名）" >&2
  exit 1
fi

# 切到仓库根（脚本位于 scripts/ 下）
cd "$(cd "$(dirname "$0")" && pwd)/.."

if ! command -v fastlane >/dev/null 2>&1; then
  echo "错误：未找到 fastlane，请先安装：brew install fastlane" >&2
  exit 1
fi

ARGS=(ios package env:"$ENV_NAME" distribute:"$DISTRIBUTE")
if [[ -n "$VERSION" ]]; then
  ARGS+=(version:"$VERSION")
fi

echo "==> CalmTrack：env=${ENV_NAME} distribute=${DISTRIBUTE}${VERSION:+  version=${VERSION}}（build 号自动递增）"
echo "==> 命令：fastlane ${ARGS[*]}"
fastlane "${ARGS[@]}"
