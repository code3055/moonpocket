# MoonPocket · 时间口袋

把一天的安排变成可解释的专注时间报告：有多少空闲时间真正连得起来？每次会议结束后重新进入状态，会吃掉多少时间？如果可以移走一场安排，哪一场最能找回完整时间？

这是一个以 **MoonBit 为主要语言** 的小工具。解析、区间合并、专注时段计算、逐项移除模拟、JSON 与 SVG 生成都在 MoonBit 核心中完成。Node.js 仅承接 CLI 文件读写、进程退出码和报告阈值读取。无需安装第三方库，不访问日历或网络。

## 快速体验

先安装 [MoonBit 官方工具链](https://www.moonbitlang.com/download/)（moonc 至少 v0.10.14）和 [Node.js](https://nodejs.org/)（建议 22 或更新版本），然后获取项目：

```bash
git clone https://github.com/code3055/moonpocket.git
cd moonpocket
moon check --target js --deny-warn
moon test --target js --deny-warn
moon build --target js src/cmd/moonpocket
node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input examples/fragmented.day --report examples/fragmented-report.json --svg examples/fragmented.svg
```

以上适用于工具链已加入 PATH 的 Windows、Linux 或 macOS。

当前工作区已有工具链：

```powershell
$env:MOON_HOME = 'E:\moonbit\moonbit-cli'
& "$env:MOON_HOME/bin/moon.exe" build --target js src/cmd/moonpocket
node _build/js/debug/build/cmd/moonpocket/moonpocket.js --input examples/fragmented.day --report examples/fragmented-report.json --svg examples/fragmented.svg
```

也可以使用包装脚本 `./moonpocket.ps1 --input examples/quiet.day`。脚本优先使用有效的 MOON_HOME，否则查找项目相邻的 moonbit-cli 目录；在其他机器上先把 MOON_HOME 设为自己的 MoonBit 工具链路径。所有命令从项目根目录运行。

已生成的示例：[碎片日程报告](examples/fragmented-report.json)、[碎片日程时间轴](examples/fragmented.svg)、[安静日程时间轴](examples/quiet.svg)。默认门槛 45 分钟、恢复 10 分钟时，碎片日程有 345 分钟空闲，但只有 130 分钟专注时间；把 30 分钟 review 挪到当天之外，专注时间增加 110 分钟。

## 输入格式

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

| 参数 | 作用 | 默认 |
| --- | --- | --- |
| `--input <file>` | 文本日程快照 | 内置碎片日程 |
| `--report <file>` | 保存 JSON，同时 stdout 输出 JSON | 不保存 |
| `--svg <file>` | 保存独立 SVG 时间轴 | 不保存 |
| `--min-focus <n>` | 专注时段最短分钟数，1—1440 | 45 |
| `--recovery <n>` | 忙碌后恢复分钟数，0—1440 | 10 |
| `--require-focus <n>` | 专注预算门槛，0—1440 | 0 |

退出码：`0` 完成并达到预算；`1` 完成但未达到预算；`2` 参数、输入或读写错误。输出目录需要预先存在。示例：在 CI 中使用 `--require-focus 180` 检查团队约定的日程快照。工具不自动改动任何日程。

## MoonBit API

```moonbit
match @core.analyze_text("day 09:00 18:00\nbusy lunch 12:00 13:00", 45, 10) {
  Ok(json) => println(json)
  Err(message) => println(message)
}
```

使用 API 的包名为 `code3055/moonpocket/core`。`@core.svg_from_text(text, min_focus, recovery)` 返回 `Result[String, String]`，可单独生成时间轴。核心不含文件读写或全局状态。同样的输入和参数产生相同输出。

## 验证

```powershell
$env:MOON_HOME = 'E:\moonbit\moonbit-cli'
& "$env:MOON_HOME/bin/moon.exe" fmt
& "$env:MOON_HOME/bin/moon.exe" check --target js --deny-warn
& "$env:MOON_HOME/bin/moon.exe" test --target js --deny-warn
& "$env:MOON_HOME/bin/moon.exe" build --target js src/cmd/moonpocket
node --test tests/cli.integration.test.mjs
```

## 发布到 Mooncakes

模块配置为 `code3055/moonpocket`。请使用 Mooncakes 用户名 `code3055` 登录；首次使用先运行 `moon register`，已有账号运行 `moon login`。登录成功后，在项目根目录依次运行 `moon package --list`、`moon publish --dry-run` 检查打包文件和远端预检，最后运行 `moon publish` 发布 `0.1.0`。本地预检收到 `202 Accepted: Dry run completed successfully`，且明确没有写入远端；当前工具链在显示该成功消息后仍可能以退出码 1 结束，因此请以服务器返回的具体消息判断预检结果。发布后检查 `https://mooncakes.io/code3055/moonpocket`。版本号一旦发布不能重复发布；后续更新需先在 `moon.mod` 增加版本号。详见 [官方发布指南](https://docs.moonbitlang.com/en/latest/toolchain/moon/package-manage-tour.html)。

## 参考项目浅析

[MoonLayout Audit](https://github.com/hua1104/MoonLayout) 是图布局快照的质量审计库，检查节点重叠、越界、边交叉和边长，生成稳定指纹、JSON 报告与 SVG 问题标注。它的主要源码是 MoonBit（`layout.mbt`、`svg.mbt` 和 CLI），JS 目标提供命令行文件访问，Node.js 编写 CLI 集成测试。项目还有示例快照、CI 和使用文档。

MoonPocket 借鉴的是“纯计算库 → 可审阅文本快照 → 机器报告与可视化 → CLI 质量门槛 → 测试和示例”这套模式。新工具的内容是日程碎片与专注时间回收；不包含图布局检查，也未复制参考项目代码。详见 [项目设计说明](docs/DESIGN.md)。

MIT License.


