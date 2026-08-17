#!/usr/bin/env bash
# pi 汉化版（yuloop/pi）一键安装脚本 —— Linux x64（含 WSL）
#
# 用法：
#   install.sh                安装最新正式版（*-cn，跟随上游正式 Release，稳定）
#   install.sh --preview      安装最新实时预览版（*-cn-nightly，跟随上游 main 每小时构建）
#   install.sh --version TAG  安装指定版本（如 v0.84.2-cn-nightly-0123456789ab）
#   install.sh --help         显示帮助
#
# 安装目录：~/.pi-cn（用户数据在 ~/.pi/agent，与安装目录无关，可放心覆盖）
set -euo pipefail

API="https://api.github.com/repos/yuloop/pi/releases"
DL="https://github.com/yuloop/pi/releases/download"

MODE="stable"
SPECIFIC_TAG=""

usage() {
  cat <<'EOF'
用法：
  install.sh                安装最新正式版（稳定，跟随上游正式 Release）
  install.sh --preview      安装最新实时预览版（*-cn-nightly）
  install.sh --version TAG  安装指定版本（如 v0.84.2-cn-nightly-0123456789ab）
  install.sh --help         显示本帮助
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview) MODE="preview" ;;
    --version)
      SPECIFIC_TAG="${2:-}"
      if [[ -z "$SPECIFIC_TAG" ]]; then
        echo "错误：--version 需要带版本 tag（如 v0.84.2-cn）" >&2
        exit 1
      fi
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "错误：未知参数 '$1'（用 --help 查看用法）" >&2
      exit 1
      ;;
  esac
  shift
done

# 仅支持 Linux x86_64（含 WSL）
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "错误：当前平台 $(uname -s)/$(uname -m) 暂不支持，仅支持 Linux x86_64（含 WSL）" >&2
  exit 1
fi

# curl / wget 任一可用
if command -v curl >/dev/null 2>&1; then
  get() { curl -fsSL "$1"; }
  dl()  { curl -fsSL -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  get() { wget -qO- "$1"; }
  dl()  { wget -qO "$2" "$1"; }
else
  echo "错误：未找到 curl 或 wget，请先安装其一" >&2
  exit 1
fi

# 拉取 URL 内容（失败退出并报错）
fetch() {
  local out
  if ! out="$(get "$1")"; then
    echo "错误：下载失败：$1" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

# 下载到文件（失败退出并报错）
fetch_file() {
  if ! dl "$1" "$2"; then
    echo "错误：下载失败：$1" >&2
    exit 1
  fi
}

# 解析目标版本 tag
resolve_tag() {
  if [[ -n "$SPECIFIC_TAG" ]]; then
    printf '%s\n' "$SPECIFIC_TAG"
    return
  fi
  local tag
  if [[ "$MODE" == "preview" ]]; then
    # 预览版：releases 前 10 条中第一个 prerelease==true 且 tag 含 -cn-nightly 的条目
    tag="$(fetch "${API}?per_page=10" \
      | grep -oE '"tag_name": *"[^"]*"|"prerelease": *(true|false)' \
      | sed -E 's/.*"tag_name": *"([^"]*)"/TAG \1/; s/.*"prerelease": *(true|false)/PRE \1/' \
      | awk '$1=="TAG"{t=$2} $1=="PRE" && $2=="true" && t ~ /cn-nightly/{print t; exit}')"
  else
    # 正式版：releases/latest（GitHub 自动排除 prerelease）
    tag="$(fetch "${API}/latest" \
      | grep -oE '"tag_name": *"[^"]*"' | head -1 \
      | sed -E 's/.*"tag_name": *"([^"]*)"/\1/')"
  fi
  if [[ -z "$tag" ]]; then
    local kind="正式版"
    [[ "$MODE" == "preview" ]] && kind="实时预览版"
    echo "错误：没有找到可用的${kind}" >&2
    exit 1
  fi
  printf '%s\n' "$tag"
}

TAG="$(resolve_tag)"
[[ "$TAG" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "错误：版本 tag 含非法字符：$TAG" >&2
  exit 1
}
echo "==> 目标版本：${TAG}"

# 从该 release 资产中按名字匹配安装包（不绑定具体版本号）与 SHA256SUMS
ASSETS="$(fetch "${API}/tags/${TAG}" \
  | grep -oE '"name": *"[^"]*"' \
  | sed -E 's/^"name": *"//; s/"$//')"
ARCHIVE="$(printf '%s\n' "$ASSETS" | grep -E '^pi-cn-.*-linux-x64\.tar\.gz$' | head -1 || true)"
if [[ -z "$ARCHIVE" ]]; then
  echo "错误：Release ${TAG} 中未找到 Linux x64 安装包" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 下载 ${ARCHIVE} ..."
fetch_file "${DL}/${TAG}/${ARCHIVE}" "${TMP}/${ARCHIVE}"
fetch_file "${DL}/${TAG}/SHA256SUMS" "${TMP}/SHA256SUMS"

echo "==> 校验 SHA-256 ..."
# 临时 SUMS 只保留本安装包与 SHA256SUMS 的行
awk -v a="$ARCHIVE" '{ if ($2 == a || $2 == "SHA256SUMS") print }' "${TMP}/SHA256SUMS" > "${TMP}/install.sums"
if [[ ! -s "${TMP}/install.sums" ]]; then
  echo "错误：SHA256SUMS 中没有 ${ARCHIVE} 的摘要" >&2
  exit 1
fi
(cd "${TMP}" && sha256sum -c install.sums)

INSTALL_DIR="$HOME/.pi-cn"
echo "==> 安装到 ${INSTALL_DIR}（用户数据在 ~/.pi/agent，不受影响）..."
rm -rf -- "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
tar -xzf "${TMP}/${ARCHIVE}" -C "${INSTALL_DIR}"

# PATH：~/.pi-cn 不在 PATH 时追加到 ~/.bashrc（幂等）
PATH_LINE='export PATH="$HOME/.pi-cn:$PATH"'
case ":$PATH:" in
  *":$HOME/.pi-cn:"*) echo "==> PATH：~/.pi-cn 已在当前 PATH 中" ;;
  *)
    if grep -qF "$PATH_LINE" "$HOME/.bashrc" 2>/dev/null; then
      echo "==> PATH：~/.bashrc 已包含该行（跳过）"
    else
      printf '%s\n' "$PATH_LINE" >> "$HOME/.bashrc"
      echo "==> PATH：已追加到 ~/.bashrc（新开终端即可直接输入 pi）"
    fi
    ;;
esac

echo ""
echo "安装完成：pi-cn ${TAG}"
echo "安装目录：${INSTALL_DIR}"
echo "运行命令：${INSTALL_DIR}/pi   （或新开终端直接输入 pi）"
echo "更新：重跑同一条安装命令即可"