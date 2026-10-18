# 本地验证记录

2026-10-18，使用 E:/moonbit/moonbit-cli，moon 0.1.20260920。

- moon fmt --check：通过。
- moon check --target js --deny-warn：通过，零警告。
- moon test --target js --deny-warn：6 项核心测试通过。
- moon build --target js src/cmd/moonpocket：通过。
- node --test tests/cli.integration.test.mjs：8 项通过，其中独立逐分钟 oracle 验证 24 组随机日程及每条移除建议。
- moon info：通过，公开 API 文件已生成。
- moonpocket.ps1 --input examples/quiet.day --require-focus 400：通过，返回 470 专注分钟。
- 两份示例报告与 SVG：实际通过 CLI 生成，SVG XML 解析通过；碎片示例另经本地 Edge 无界面渲染，截图为 examples/fragmented-preview.png。

验证范围为本地 JS 目标；GitHub CI 配置已提供，但尚未在远端执行。未验证 native/wasm 目标；CLI 使用 JS 文件读写接口。建议仅计算时间收益，不评估安排重要性、能否移动或真实专注表现。
