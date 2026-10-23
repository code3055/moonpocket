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

## 精确求解模式

`--mode plan --tasks tasks.txt` 会在当天的可用窗口中安排任务。任务行格式为：

```text
task write 30 09:00 12:00 5 deep
task email 20 10:00 12:00 2 shallow
after email write
```

任务有释放时间、截止时间、价值和上下文；`after CHILD PARENT` 声明依赖。求解器用 `mask,last` 动态规划保留每个已选任务集合和最后上下文的最早结束状态，目标依次为总价值、完成数量和较早结束时间。最多 14 个任务，返回排程、未排原因、状态数量和转移数量。

```powershell
node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input examples/quiet.day --mode plan --tasks tasks.txt --switch 5
```

`--mode reclaim` 则在预算内联合移除可移动 `busy` 安排；`fixed` 永远保留。可选成本文件使用 `cost EVENT_ID POSITIVE_INT`，最多 16 个可移动安排，完整枚举所有子集并输出每个未被支配的成本-专注时间点：

```powershell
node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input examples/protected.day --mode reclaim --target 180 --budget 5 --costs costs.txt
```

这两个模式的上限是精确性和可审计性的边界，不是对任意规模排程的承诺。算法细节和复杂度见 [联合回收算法说明](RECLAIM_ALGORITHM.md)。

## 作为 MoonBit 库使用

模块同时提供类型化 API。`analyze_schedule` 返回 `Report`，`compare_schedules` 返回 `AnalysisDelta`，适合编辑器、机器人或其他 MoonBit 工具在内存中复用；不必启动 CLI，也不必解析 JSON。`examples/library-consumer.mbt` 展示了最小的版本对比调用。当前发布包版本为 `0.2.1`，接口变更和算法上限会记录在模块版本中。

## 多日、资源和目标策略

周期输入包含一个日模板和重复规则：

```text
day 09:00 18:00
repeat 0 7 busy standup 09:30 10:00
repeat 2 7 fixed exam 14:00 15:00
```

`expand_recurrence(text, days)` 返回每一天独立的 `.day` 快照，调用方可以逐日分析或保存结果。`FIRST` 是首个日索引，`PERIOD` 是重复周期；当前模型最多展开 366 天，日期标签由上层日历系统决定。

任务文件支持资源窗口和三种目标策略：

```text
resource gpu 09:00 10:00
task render 30 09:00 11:00 8 batch gpu
task note 30 09:00 11:00 3 writing
```

CLI 使用 `--strategy value|count|finish` 选择目标。资源约束和策略是求解器输入的一部分，报告会保留目标、状态数和未排原因。

并发任务使用库 API `parallel_schedule(day, tasks, capacities, recovery)`，容量文件示例为 `capacity gpu 2`；它允许同一资源在容量范围内重叠，并返回每个任务的资源和时间。`expand_dated_recurrence` 在周期展开之上增加 `YYYY-MM-DD` 起始日期、`-840..840` 分钟固定 UTC 偏移和例外日期数组。

`tests/benchmark.mjs` 是可重复的本地规模基准，当前测量 12 个任务、20 次运行的平均 CLI 排程耗时；它不是功能测试，输出 JSON 便于在不同 MoonBit/Node 版本间比较。

## 验证发布包

```powershell
$env:MOON_HOME = 'E:moonbitmoonbit-cli'
node tests/package.integration.mjs
```

该脚本使用 Python 标准库解压发布包，在独立目录完成代码检查、核心测试、构建、CLI 测试和示例验证；Python 仅用于验证，不是工具运行依赖。CI 包含同样流程。
