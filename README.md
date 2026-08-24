# Pi（π）简体中文汉化版

[![CI](https://github.com/yuloop/pi/actions/workflows/ci.yml/badge.svg)](https://github.com/yuloop/pi/actions/workflows/ci.yml)
[![Auto Release](https://github.com/yuloop/pi/actions/workflows/pi-cn-release.yml/badge.svg)](https://github.com/yuloop/pi/actions/workflows/pi-cn-release.yml)
[![Latest Release](https://img.shields.io/github/v/release/yuloop/pi?label=最新版)](https://github.com/yuloop/pi/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 汉化版与官方版差异

和上游官方版（earendil-works/pi）相比，本仓库做了以下改进与补充：

| 维度 | 官方版（earendil-works/pi） | 本仓库（汉化版） |
|---|---|---|
| 中文支持 | 无 | 约 200+ 翻译词条，覆盖 TUI 核心交互模块 |
| 构建自动化 | 无 | 每小时自动同步+构建+发布 |
| 一键安装 | 无 | install.ps1 / install.sh |
| 预览版（Nightly） | 无 | 跟随上游 main 分支，4次/天自动构建 |
| 发布平台 | 源码为主 | Linux x64 + Windows x64 便携二进制 |
| 翻译门禁 | 无 | 100% 唯一匹配门禁后才允许发布 |
| upstream 追踪 | — | 每小时检查上游 main 分支 |
| 汉化文件 | 无 | pi-i18n/ 全量新增（官方仓库无此目录） |

> 非官方项目，与 earendil-works 官方团队没有隶属关系。模型配置、扩展、工作目录格式均沿用官方 Pi。

## 支持平台

| 平台 | 汉化版 Pi |
|---|---:|
| Linux x64 / WSL |  |
| Windows x64 |  |
| macOS / ARM64 | 暂未自动发布 |

## 快速安装

从 [Releases](https://github.com/yuloop/pi/releases/latest) 下载对应平台压缩包，解压后运行 `pi`。

### Linux x64

```bash
pi-cn-tool download
pi
```

### Windows x64

```powershell
.\pi-cn-tool.exe download
.\pi.exe
```

## 自动汉化流程

```text
上游官方 Release / main commit
        ↓ 每小时检查
同步上游源码
        ↓
应用简体中文翻译（pi-i18n/translations/*.json，100% 匹配门禁）
        ↓
构建 Linux x64 + Windows x64 二进制
        ↓
发布到 GitHub Releases
```

本地修改文件：`pi-i18n/translations/*`（20+ JSON 翻译文件）、`install.sh`、`install.ps1`、`.github/workflows/pi-cn-{sync,release,nightly}.yml`

## 许可证

MIT — 与官方 Pi 保持一致。

汉化翻译文件由 yuloop 社区维护，遵循原项目的 MIT 许可证。
