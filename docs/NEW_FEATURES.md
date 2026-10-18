# 实用功能补充

## 保护不可移动的安排

`fixed` 与 `busy` 都占用时间；只有 `busy` 会被尝试移除。两类安排共享标识符空间。

```text
day 09:00 18:00 # 单日范围
fixed lunch 12:00 13:00
fixed exam 14:00 15:00
busy review 15:30 16:00
```

支持 UTF-8 BOM、CRLF 和行尾注释。`#` 必须位于一个词的开始位置，如 `a#b` 仍是无效标识符。

## Markdown 和日历导出

```powershell
.moonpocket.ps1 --input examples/protected.day --markdown focus.md --svg focus.svg --ics focus.ics --date 2026-10-18
```

Markdown 列出可用专注时段和移除收益，可放入笔记或代码评审。SVG 包含时间刻度、悬停说明及 `[fixed]` 标记。ICS 只包含合格专注时段；忙碌后的开始时间已扣除恢复时间，24:00 自动转换为次日 00:00。

日历时间没有时区标记，导入时按日历客户端的本地时区解释。日期要求有效的 YYYY-MM-DD，年份 0001—9998。没有合格时段时生成空日历。导入之前请确认日期、时区和安排；工具仅生成文件，不访问日历账号。

## 从标准输入分析

```powershell
Get-Content examples/protected.day -Raw | node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input -
```

## 验证发布包

```powershell
$env:MOON_HOME = 'E:moonbitmoonbit-cli'
node tests/package.integration.mjs
```

该脚本使用 Python 标准库解压发布包，在独立目录完成代码检查、核心测试、构建、CLI 测试和示例验证；Python 仅用于验证，不是工具运行依赖。CI 包含同样流程。
