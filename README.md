# Pi（π）简体中文汉化版

[![CI](https://github.com/yuloop/pi/actions/workflows/ci.yml/badge.svg)](https://github.com/yuloop/pi/actions/workflows/ci.yml)
[![Auto Release](https://github.com/yuloop/pi/actions/workflows/pi-cn-release.yml/badge.svg)](https://github.com/yuloop/pi/actions/workflows/pi-cn-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/yuloop/pi?label=最新版)](https://github.com/yuloop/pi/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

这是 AI 编码助手 **Pi**（[earendil-works/pi](https://github.com/earendil-works/pi)）的社区简体中文汉化版。

本仓库每小时自动检查上游官方仓库 `main` 分支：有新提交时自动同步源码 → 应用简体中文翻译（已维护词条 100% 唯一匹配门禁）→ 构建 Linux x64 / Windows x64 便携版 → 发布到 [Releases](https://github.com/yuloop/pi/releases)。

> 非官方项目，与 earendil-works 官方团队没有隶属关系。模型配置、扩展、工作目录格式均沿用官方 Pi。

## 支持平台

| 平台 | 汉化版 Pi |
|---|---:|
| Linux x64 / WSL | ✅ |
| Windows x64 | ✅ |
| macOS / ARM64 | 暂未自动发布 |

## 快速安装

从 [Releases](https://github.com/yuloop/pi/releases/latest) 下载对应平台压缩包，解压后运行 `pi`。

### Linux x64

```bash
curl -fsSL -o pi-cn.tar.gz https://github.com/yuloop/pi/releases/latest/download/pi-cn-<版本>-linux-x64.tar.gz
tar xzf pi-cn.tar.gz
./pi
```

### Windows x64

下载 `pi-cn-<版本>-windows-x64.zip`，解压后运行 `pi.exe`。

建议将解压目录加入 `PATH`；首次运行按提示配置模型提供商（默认使用 `opencode-go` 等已配置的 OpenAI 兼容端点）。

## 与官方版的关系

- 汉化仅修改用户可见界面文案（TUI / CLI 帮助、提示、错误信息），**不改变功能、配置格式与数据格式**
- 每小时自动跟随上游更新；上游发布新版本后本仓库自动构建发布汉化版
- 自动化不会修改你机器上的官方安装

## 自动汉化工作原理

```text
earendil-works/pi main 分支
        ↓ 每小时检查
检出上游最新源码
        ↓
已维护翻译词条执行 100% 唯一匹配门禁
        ↓ 通过
构建 Linux x64 / Windows x64
        ↓
生成 SHA256SUMS 并发布 <上游版本>-cn Release
```

- 翻译以源码字符串替换规则维护（[pi-i18n/translations](pi-i18n/translations)），当前基线：上游 `v0.84.1`
- 上游改动导致任何词条失配时，流水线会**失败并停止发布**；维护者确认新文案后再更新词表——避免发布"半汉化"版本
- 这里说的"自动汉化"是自动跟踪、套用已审核译文、验证并构建发布，不是把新文本直接交给机器翻译

手动运行发布：Actions → `Pi Chinese Release` → Run workflow，可指定上游分支/commit 或发布 tag；留空使用最新 `main`。

## 源码结构（来自上游）

| 包 | 说明 |
|---|---|
| **@earendil-works/pi-coding-agent**（`packages/coding-agent`） | 交互式编码 Agent CLI |
| **@earendil-works/pi-agent-core**（`packages/agent`） | 带工具调用与状态管理的 Agent 运行时 |
| **@earendil-works/pi-ai**（`packages/ai`） | 统一多提供商 LLM API（OpenAI、Anthropic、Google 等） |
| **@earendil-works/pi-tui**（`packages/tui`） | 差分渲染终端 UI 库 |

更多信息见官方站点 [pi.dev](https://pi.dev)。

## 权限与容器化

Pi 不内置文件系统/进程/网络/凭据访问的权限系统，默认以启动它的用户权限运行。需要更强隔离时请容器化或沙箱化，参见 [packages/coding-agent/docs/containerization.md](packages/coding-agent/docs/containerization.md) 中的三种模式（Gondolin 扩展 / Docker / OpenShell）。

## 开发

```bash
npm install --ignore-scripts  # 安装依赖但不执行生命周期脚本
npm run build                 # 刷新模型数据并构建所有包
npm run check                 # 代码检查、格式、类型检查
./test.sh                     # 运行测试
```

## 汉化维护

- 翻译词表：`pi-i18n/translations`（JSON，按源码文件组织）
- 翻译工具：`pi-i18n/apply_translations.py`（`verify` / `apply` 两种模式）
- 自动流水线：`.github/workflows/pi-cn-release.yml`

本地验证词表与上游源码完全匹配：

```bash
python3 pi-i18n/apply_translations.py verify \
  --translations pi-i18n/translations --source <上游源码目录> \
  --strict --min-match-rate 1
```

## 来源与许可

- 本项目 fork 自 [earendil-works/pi](https://github.com/earendil-works/pi)，上游按 **MIT License** 发布，版权归原作者所有
- 本仓库中的翻译词表、翻译工具与自动化流水线按 [MIT License](LICENSE) 提供
- 原项目 logo、商标及名称归其各自所有者所有，本汉化版与其无隶属关系
