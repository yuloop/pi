# pi 简体中文汉化版（pi-i18n）

[earendil-works/pi](https://github.com/earendil-works/pi)（AI 编码智能体，TypeScript monorepo，含 TUI 终端界面与 coding-agent CLI）的社区汉化构建。

本仓库（yuloop/pi fork）维护：

- `pi-i18n/translations/` — 翻译词表（按源码模块拆分的 JSON，格式 `{"file": ..., "replacements": {"英文原文": "中文译文"}}`）
- `pi-i18n/apply_translations.py` — 翻译应用/校验工具（Python 3 标准库，无第三方依赖）
- `.github/workflows/pi-cn-release.yml` — 自动汉化构建发布流水线：每小时同步上游 `main` → 校验词表 100% 匹配 → 应用翻译 → 构建 → 发布 `<上游版本>-cn` Release

汉化版与上游同步机制：流水线每小时检查上游 `earendil-works/pi` 的 `main` 分支是否有新提交；只有新提交时才会拉取、汉化、构建并发布。若上游无新变化则跳过（不产生空 Release）。

## 汉化版安装

### 一键安装（推荐）

**正式版**（跟随上游正式 Release，稳定）：

Windows PowerShell：

```powershell
powershell -Command "irm https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install.ps1 | iex"
```

Linux（含 WSL）：

```bash
curl -fsSL https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install.sh | bash
```

**实时预览版**（跟随上游 `main` 每提交构建，Releases 页面只保留最新 1 个预览条目）：

Windows PowerShell：

```powershell
powershell -Command "irm https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install-preview.ps1 | iex"
```

Linux（含 WSL）：

```bash
curl -fsSL https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install.sh | bash -s -- --preview
```

> 说明：预览版重跑同一命令即更新；正式版与预览版安装目录相同（`~/.pi-cn` / `%LOCALAPPDATA%\pi-cn`），互斥安装属正常（同一时刻用一条线）。

### 手动安装（下载 Releases 包）

以下为手动方式，推荐上面的一键安装。

从 [Releases](https://github.com/yuloop/pi/releases) 页面下载对应平台的汉化包（tag 形如 `v0.84.1-cn`，`0.84.1` 为上游版本号，预览版 tag 形如 `v0.84.1-cn-nightly-<sha12>`）。

### Linux x64（含 WSL）

```bash
# 1. 下载并解压（把 v0.84.1 替换为实际版本号）
curl -fsSL -o pi-cn.tar.gz "https://github.com/yuloop/pi/releases/download/v0.84.1-cn/pi-cn-0.84.1-linux-x64.tar.gz"
mkdir -p ~/.pi-cn && tar -xzf pi-cn.tar.gz -C ~/.pi-cn

# 2. 运行
~/.pi-cn/pi

# 3. （可选）加入 PATH
echo 'export PATH="$HOME/.pi-cn:$PATH"' >> ~/.bashrc
```

### Windows x64

1. 下载 `pi-cn-<版本>-windows-x64.zip` 并解压到任意目录（如 `C:\pi-cn`）；
2. 双击或命令行运行目录内的 `pi.exe`。

### 从源码安装（汉化源码包）

下载 `pi-cn-<版本>-source.tar.gz`，解压后：

```bash
npm ci --ignore-scripts
npm run build
# 运行
node packages/coding-agent/dist/cli.js
```

## 更新汉化版

汉化版每个小时自动跟随上游同步（上游有新提交时自动发布新 Release，tag 版本号随之更新）。更新方式：

- **一键安装（推荐）**：重跑上面的一键安装命令即自动更新到最新版；
- **重新下载**：到 [Releases](https://github.com/yuloop/pi/releases) 下载最新版，覆盖解压目录即可；
- **Linux 提示**：替换 `~/.pi-cn` 目录下的文件后重新运行；
- 汉化版配置与官方版共用同一配置目录（`~/.pi/agent`），更新不会丢失会话与设置。

> 提示：如果只想升级而保留旧版，可解压到新目录（如 `~/.pi-cn-0.85.0`）再切换 PATH。

## 卸载汉化版

```bash
# Linux：删除解压目录与 PATH 配置
rm -rf ~/.pi-cn
sed -i '/pi-cn/d' ~/.bashrc
```

Windows：删除解压目录即可。

> 卸载汉化版**不会**删除你的会话数据与配置（位于 `~/.pi/agent`，与官方版共用）。

## 翻译词表

`pi-i18n/translations/` 按源码模块组织，每个 JSON 对应一个源文件：

```json
{
  "file": "packages/coding-agent/src/modes/interactive/interactive-mode.ts",
  "description": "交互模式主界面（状态提示、快捷键说明、slash 命令反馈）",
  "replacements": {
    "Keyboard Shortcuts": "键盘快捷键",
    "✓ New session started": "✓ 已开启新会话"
  }
}
```

翻译范围与原则：

- 只翻译用户可见的 TUI/CLI 界面文案（按钮、提示、状态、错误、快捷键说明、帮助文本）；
- 不翻译代码标识符、文件名、URL、API/模型名、命令名、设置值（如 `all`/`scoped`）以及用于逻辑比较的字符串；
- 保留全部占位符（`${...}`、`{name}`、`%s`、`\n` 等），译文占位符与原文一一对应（`${...}` 表达式内部文本允许翻译，数量必须一致）；
- 术语统一：agent=智能体、model=模型、tool=工具、prompt=提示词、workspace=工作区、session=会话、provider=提供商。

## 翻译工具

```bash
# 校验：词表每条原文在源码中唯一匹配（缺失/歧义/占位符不一致即失败）
python3 pi-i18n/apply_translations.py verify \
  --translations pi-i18n/translations --source . --strict --min-match-rate 1

# 应用：把词表替换进源码（--dry-run 仅预览）
python3 pi-i18n/apply_translations.py apply \
  --translations pi-i18n/translations --source . --strict --min-match-rate 1
```

发布门禁：`translation-gate` 阶段要求 `verify --strict --min-match-rate 1`（100% 匹配）通过后才允许构建与发布；上游源码变更导致词条失配时，流水线会失败并提示维护词表。

> 本项目是社区维护的非官方汉化构建，与 pi 官方团队无隶属关系。
