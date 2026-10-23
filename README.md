# MoonPocket · 时间口袋

把一天的安排变成可解释的专注时间报告：有多少空闲时间真正连得起来？每次会议结束后重新进入状态，会吃掉多少时间？如果可以移走一场安排，哪一场最能找回完整时间？

这是一个以 **MoonBit 为主要语言** 的小工具。解析、区间合并、专注时段计算、逐项移除模拟、JSON 与 SVG 生成都在 MoonBit 核心中完成。Node.js 仅承接 CLI 文件读写、进程退出码和报告阈值读取。无需安装第三方库，不访问日历或网络。

## 快速体验

当前工作区已有工具链：

```powershell
$env:MOON_HOME = 'E:\moonbit\moonbit-cli'
& "$env:MOON_HOME/bin/moon.exe" build --target js src/cmd/moonpocket
node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input examples/fragmented.day --report examples/fragmented-report.json --svg examples/fragmented.svg
```

也可以使用包装脚本 `./moonpocket.ps1 --input examples/quiet.day`。脚本优先使用有效的 MOON_HOME，否则查找项目相邻的 moonbit-cli 目录；在其他机器上先把 MOON_HOME 设为自己的 MoonBit 工具链路径。所有命令从项目根目录运行。

已生成的示例：[碎片日程报告](examples/fragmented-report.json)、[碎片日程时间轴](examples/fragmented.svg)、[安静日程时间轴](examples/quiet.svg)。默认门槛 45 分钟、恢复 10 分钟时，碎片日程有 345 分钟空闲，但只有 130 分钟专注时间；把 30 分钟 review 挪到当天之外，专注时间增加 110 分钟。

## 输入格式

新增 `fixed` 保护不可移动安排，支持 BOM 与行尾注释；还可使用 `--markdown` 输出笔记报告、`--ics` 和 `--date` 输出专注时段日历，以及 `--input -` 读取管道输入。完整命令和时间解释见 [功能补充说明](docs/NEW_FEATURES.md)。

在同一个 CLI 中还提供两个精确求解模式：`--mode plan` 用带依赖、释放时间、截止时间、上下文切换成本的子集动态规划安排任务；`--mode reclaim` 在预算内联合移除可移动安排，输出最优方案和成本-专注时间前沿。两者均输出可复核 JSON，适合把日程快照放进 CI 或评审流程。

```text
# 支持空行与整行注释；安排可乱序，也可重叠
day 09:00 18:00
busy standup 09:30 10:00
busy lunch 12:00 13:00
busy sync 14:00 14:30
```

`day` 必须恰好一条；时间为严格的 24 小时 `HH:MM`，区间左闭右开。`24:00` 只能作为结束时间。busy 标识符使用 ASCII 字母、数字、下划线或连字符，不可重复，长度最多 64 字符。安排必须处于当天范围内，最多 200 条。不支持跨午夜、多个日期、ICS 导入和循环日程。

## 算法与新意

先合并重叠或相接的忙碌区间，然后提取空闲间隙。一天开始的间隙可以直接使用；忙碌区间后的间隙先扣除恢复时间。可用长度达到 `--min-focus` 的间隙才计入专注分钟。

例如 10:00—11:00 空闲、恢复时间 10 分钟时，可用时段为 10:10—11:00，即 50 分钟。如果专注门槛是 60 分钟，这段空闲不能计入专注预算。门槛是用户的假设，不是心理学测量。

工具会分别移除每条 busy 并重新计算；只列出能增加专注分钟的结果，按收益降序、标识符升序排列。这是“假如这场安排能挪到当天之外”的模拟，实际调整由用户决定。重叠安排的收益依据重新合并后的结果计算。

JSON 中 `free_minutes` 为原始空闲分钟，`focus_minutes` 为达到门槛的可用分钟，`fragment_minutes` 包含未能成为专注时间的空闲部分（包括恢复时间）；两者之和等于 free_minutes。`largest_focus` 为达到门槛的最长专注口袋，没有合格口袋时为 0。

## 命令行

| 参数                    | 作用                        | 默认     |
| --------------------- | ------------------------- | ------ |
| `--input <file>`      | 文本日程快照                    | 内置碎片日程 |
| `--report <file>`     | 保存 JSON，同时 stdout 输出 JSON | 不保存    |
| `--svg <file>`        | 保存独立 SVG 时间轴              | 不保存    |
| `--min-focus <n>`     | 专注时段最短分钟数，1—1440          | 45     |
| `--recovery <n>`      | 忙碌后恢复分钟数，0—1440           | 10     |
| `--require-focus <n>` | 专注预算门槛，0—1440             | 0      |
| `--mode plan` | 任务排程求解，需配 `--tasks <file>` | `audit` |
| `--mode reclaim` | 预算内联合移除求解，可配 `--costs`、`--target`、`--budget` | `audit` |
| `--switch <n>` | 排程中不同上下文之间的切换分钟数 | 0 |

退出码：`0` 完成并达到预算；`1` 完成但未达到预算；`2` 参数、输入或读写错误。输出目录需要预先存在。示例：在 CI 中使用 `--require-focus 180` 检查团队约定的日程快照。工具不自动改动任何日程。

## MoonBit API

```moonbit
match @core.analyze_text("day 09:00 18:00\nbusy lunch 12:00 13:00", 45, 10) {
  Ok(json) => println(json)
  Err(message) => println(message)
}
```

`@core.svg_from_text(text, min_focus, recovery)` 返回 `Result[String, String]`，可单独生成时间轴。核心不含文件读写或全局状态。同样的输入和参数产生相同输出。

类型化 API 包括 `@core.analyze_schedule`、`@core.compare_schedules`、`@core.plan_schedule(day, tasks, recovery, switch_minutes)` 和 `@core.reclaim_schedule(day, min_focus, recovery, target, budget, costs)`；字符串包装 API 分别为 `analyze_text`、`plan_from_text` 和 `reclaim_from_text`。`compare_schedules` 直接返回两个版本的忙碌、空闲和专注变化，不需要调用方解析 JSON。最小库消费者示例见 [library-consumer.mbt](examples/library-consumer.mbt)。排程最多 14 个任务，联合移除最多 16 个可移动安排，这是为了保留精确解和可解释的穷举证明。

排程任务可以追加资源名，例如 `task render 30 09:00 11:00 8 batch gpu`，并在任务文件中声明 `resource gpu 09:00 10:00`。任务必须同时满足专注窗口和资源窗口。`plan_schedule_with_strategy` 支持 `value`、`count`、`finish` 三种目标策略；周期日程可用 `expand_recurrence` 将重复规则展开为多个独立日快照，最多 366 天。

## 验证

```powershell
$env:MOON_HOME = 'E:\moonbit\moonbit-cli'
& "$env:MOON_HOME/bin/moon.exe" fmt
& "$env:MOON_HOME/bin/moon.exe" check --target js --deny-warn
& "$env:MOON_HOME/bin/moon.exe" test --target js --deny-warn
& "$env:MOON_HOME/bin/moon.exe" build --target js src/cmd/moonpocket
node --test tests/cli.integration.test.mjs
node --test tests/solver.integration.test.mjs
```

## 参考项目浅析

[MoonLayout Audit](https://github.com/hua1104/MoonLayout) 是图布局快照的质量审计库，检查节点重叠、越界、边交叉和边长，生成稳定指纹、JSON 报告与 SVG 问题标注。它的主要源码是 MoonBit（`layout.mbt`、`svg.mbt` 和 CLI），JS 目标提供命令行文件访问，Node.js 编写 CLI 集成测试。项目还有示例快照、CI 和使用文档。

MoonPocket 借鉴的是“纯计算库 → 可审阅文本快照 → 机器报告与可视化 → CLI 质量门槛 → 测试和示例”这套模式。新工具的内容是日程碎片与专注时间回收；不包含图布局检查，也未复制参考项目代码。详见 [项目设计说明](docs/DESIGN.md)。

MIT License.
