#!/usr/bin/env python3
"""pi 汉化翻译工具：按词表对 pi 源码做精确字符串替换。

用法：
  python3 apply_translations.py verify --translations <词表目录> --source <pi仓库根> [--strict] [--min-match-rate 1]
  python3 apply_translations.py apply  --translations <词表目录> --source <pi仓库根> [--dry-run] [--strict] [--min-match-rate 1]

词表格式（与参考项目一致，每个 JSON 对应一个源码文件）：
  {
    "file": "packages/.../foo.ts",
    "description": "模块说明",
    "replacements": {
      "英文原文（源码中的精确字符串）": "中文译文（保留 %s、{name}、${...}、\\n 等占位符）"
    }
  }

verify --strict：要求每条原文在目标文件中恰好出现一次（缺失或歧义均报错，退出码非 0）。
apply：按文件分组、长条目优先、占位符两阶段替换，避免条目之间互相干扰。
"""

import argparse
import json
import os
import re
import sys

SIMPLE_WORD_RE = re.compile(r"^[A-Za-z0-9]+$")


# ---------------------------------------------------------------- 词表加载

def load_translations(translations_dir):
    """递归加载词表目录下所有 *.json，返回 [{file, description, path, replacements}]。"""
    configs = []
    if not os.path.isdir(translations_dir):
        raise SystemExit(f"词表目录不存在: {translations_dir}")
    for root, _dirs, files in os.walk(translations_dir):
        for name in sorted(files):
            if not name.endswith(".json"):
                continue
            path = os.path.join(root, name)
            try:
                with open(path, encoding="utf-8") as handle:
                    data = json.load(handle)
            except (json.JSONDecodeError, OSError) as error:
                raise SystemExit(f"解析词表失败 {path}: {error}")
            if not isinstance(data, dict) or not isinstance(data.get("replacements"), dict):
                raise SystemExit(f"词表格式无效（缺少 file 或 replacements 对象）: {path}")
            if not data.get("file"):
                raise SystemExit(f"词表缺少 file 字段: {path}")
            configs.append(
                {
                    "file": data["file"],
                    "description": data.get("description", ""),
                    "path": path,
                    "replacements": data["replacements"],
                }
            )
    if not configs:
        raise SystemExit(f"词表目录中未找到任何 *.json: {translations_dir}")
    return configs


# ---------------------------------------------------------------- 匹配与替换

def count_matches(content, find):
    """统计 find 在 content 中的出现次数。纯字母数字词条按单词边界匹配，其余精确匹配。"""
    if find == "":
        return 0
    if SIMPLE_WORD_RE.match(find):
        return len(re.findall(r"\b" + re.escape(find) + r"\b", content))
    return content.count(find)


def apply_replacements(content, replacements):
    """两阶段占位符替换：先按 find 长度降序把原文替换为占位符，再统一替换为译文，
    避免先替换的短条目破坏后续长条目的匹配。"""
    ordered = sorted(
        replacements,
        key=lambda item: (-len(item[0]), item[0]),
    )
    staged = []
    for index, (find, replace) in enumerate(ordered):
        if find == "":
            continue
        placeholder = f"\x00pi-i18n-{index}\x00"
        if SIMPLE_WORD_RE.match(find):
            updated = re.sub(r"\b" + re.escape(find) + r"\b", lambda _m: placeholder, content)
        else:
            updated = content.replace(find, placeholder)
        if updated != content:
            content = updated
            staged.append((placeholder, replace))
    for placeholder, replace in staged:
        content = content.replace(placeholder, replace)
    return content


# ---------------------------------------------------------------- 变量保护

PLACEHOLDER_RE = re.compile(r"(\$\{[^}]*\}|\{[A-Za-z_][A-Za-z0-9_]*\}|%[sd])")
SIMPLE_PH_RE = re.compile(r"((?<!\$)\{[A-Za-z_][A-Za-z0-9_]*\}|%[sd])")


def check_placeholders(from_text, to_text):
    """校验译文占位符与原文对应：
    - 简单占位符（{name}、%s）：必须按序全部出现在译文中；
    - 模板表达式（${...}）：只校验数量一致（表达式内部文本允许翻译）。"""
    from_simple = SIMPLE_PH_RE.findall(from_text)
    to_simple = SIMPLE_PH_RE.findall(to_text)
    it = iter(to_simple)
    if not all(ph in it for ph in from_simple):
        return False
    from_tpl = len(PLACEHOLDER_RE.findall(from_text)) - len(from_simple)
    to_tpl = len(PLACEHOLDER_RE.findall(to_text)) - len(to_simple)
    return from_tpl == to_tpl


# ---------------------------------------------------------------- verify

def run_verify(args):
    configs = load_translations(args.translations)
    source_root = os.path.abspath(args.source)
    total = 0
    matched = 0
    missing = []  # (config_path, file, key, reason)
    ambiguous = []
    var_issues = []

    for config in configs:
        target = os.path.join(source_root, config["file"])
        if not os.path.isfile(target):
            for key in config["replacements"]:
                missing.append((config["path"], config["file"], key, "目标文件不存在"))
                total += 1
            continue
        with open(target, encoding="utf-8") as handle:
            content = handle.read()
        content = content.replace("\r\n", "\n")
        for find, replace in config["replacements"].items():
            total += 1
            if find == "":
                missing.append((config["path"], config["file"], find, "空原文"))
                continue
            count = count_matches(content, find)
            if count == 0:
                missing.append((config["path"], config["file"], find, "原文在源码中未找到"))
            elif count > 1:
                ambiguous.append((config["path"], config["file"], find, f"出现 {count} 次，匹配不唯一"))
            else:
                matched += 1
            if not check_placeholders(find, replace):
                var_issues.append((config["path"], config["file"], find, replace))

    rate = matched / total if total else 0.0
    print(f"词表文件: {len(configs)} 个，翻译条目: {total} 条，唯一匹配: {matched} 条，匹配率: {rate:.2%}")

    problems = 0
    if missing:
        print(f"\n✗ 缺失 {len(missing)} 条：")
        for path, file, key, reason in missing:
            print(f"  - [{os.path.basename(path)}] {file}: {key[:80]!r}（{reason}）")
        problems += len(missing)
    if ambiguous:
        print(f"\n✗ 歧义 {len(ambiguous)} 条：")
        for path, file, key, reason in ambiguous:
            print(f"  - [{os.path.basename(path)}] {file}: {key[:80]!r}（{reason}）")
        problems += len(ambiguous)
    if var_issues:
        print(f"\n✗ 占位符不一致 {len(var_issues)} 条（原文与译文的 %s/{{var}}/${{...}} 必须一一对应）：")
        for path, file, find, replace in var_issues:
            print(f"  - [{os.path.basename(path)}] {file}: {find[:60]!r} -> {replace[:60]!r}")
        problems += len(var_issues)

    failed = problems if args.strict else len(missing) + len(var_issues)
    if args.strict and ambiguous:
        failed = problems
    if rate < args.min_match_rate:
        print(f"✗ 匹配率 {rate:.2%} 低于门禁 {args.min_match_rate:.0%}")
        failed += 1

    if failed:
        print(f"\n验证未通过（{failed} 处问题）")
        return 1
    print("✓ 验证通过：全部条目在源码中唯一匹配，占位符一致")
    return 0


# ---------------------------------------------------------------- apply

def run_apply(args):
    configs = load_translations(args.translations)
    source_root = os.path.abspath(args.source)

    # 按目标文件分组，同一文件的所有条目基于同一份原文匹配
    by_target = {}
    for config in configs:
        by_target.setdefault(config["file"], []).append(config)

    stats = {"files": 0, "success": 0, "failed": 0, "skipped": 0, "replace_success": 0, "replace_failed": 0}
    failures = []

    for file in sorted(by_target):
        target = os.path.join(source_root, file)
        file_configs = by_target[file]
        if not os.path.isfile(target):
            stats["skipped"] += 1
            for config in file_configs:
                stats["replace_failed"] += len(config["replacements"])
                failures.append(f"✗ [{os.path.basename(config['path'])}] 目标文件不存在: {file}")
            continue

        with open(target, encoding="utf-8") as handle:
            original = handle.read()
        original = original.replace("\r\n", "\n")

        pending = []
        for config in file_configs:
            for find, replace in config["replacements"].items():
                if find == "":
                    stats["replace_failed"] += 1
                    failures.append(f"✗ [{os.path.basename(config['path'])}] 空原文条目")
                    continue
                if count_matches(original, find) == 0:
                    stats["replace_failed"] += 1
                    failures.append(f"✗ [{os.path.basename(config['path'])}] 原文未找到: {find[:80]!r}")
                    continue
                if not check_placeholders(find, replace):
                    stats["replace_failed"] += 1
                    failures.append(f"✗ [{os.path.basename(config['path'])}] 占位符不一致: {find[:60]!r}")
                    continue
                pending.append((find, replace))

        if args.dry_run:
            stats["files"] += 1
            stats["replace_success"] += len(pending)
            print(f"  [dry-run] {file}: {len(pending)}/{sum(len(c['replacements']) for c in file_configs)} 条可替换")
            continue

        content = apply_replacements(original, pending)
        if content != original:
            with open(target, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(content)
        stats["files"] += 1
        stats["replace_success"] += len(pending)
        print(f"  ✓ {file}: {len(pending)}/{sum(len(c['replacements']) for c in file_configs)} 处替换")

    print(
        f"\n统计：文件 {stats['files']} 个（跳过 {stats['skipped']}），"
        f"替换成功 {stats['replace_success']} 条，失败 {stats['replace_failed']} 条"
    )
    for failure in failures:
        print(failure)
    if failures:
        return 1
    return 0


# ---------------------------------------------------------------- main

def main():
    parser = argparse.ArgumentParser(description="pi 汉化翻译工具")
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ("verify", "apply"):
        p = sub.add_parser(name)
        p.add_argument("--translations", required=True, help="词表目录（含 *.json）")
        p.add_argument("--source", required=True, help="pi 源码仓库根目录")
        p.add_argument("--dry-run", action="store_true", help="仅模拟，不写文件")
        p.add_argument("--strict", action="store_true", help="严格模式：缺失或歧义即失败")
        p.add_argument("--min-match-rate", type=float, default=0.0, help="最低匹配率门禁（0-1）")

    args = parser.parse_args()
    if args.min_match_rate < 0 or args.min_match_rate > 1:
        raise SystemExit("--min-match-rate 必须在 0 到 1 之间")

    if args.command == "verify":
        sys.exit(run_verify(args))
    else:
        sys.exit(run_apply(args))


if __name__ == "__main__":
    main()
