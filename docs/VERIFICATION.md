# 本地验证记录

2026-10-21，使用 E:/moonbit/moonbit-cli，moon 0.1.20260920。

- moon fmt --check：通过。
- moon check --target js --deny-warn：通过，零警告。
- moon test --target js --deny-warn：26 项核心测试通过。
- moon build --target js src/cmd/moonpocket：通过。
- node --test tests/cli.integration.test.mjs：11 项通过，其中独立逐分钟 oracle 验证 24 组随机日程及每条移除建议。
- node --test tests/solver.integration.test.mjs：2 项通过，独立排列 oracle 验证 48 组任务排程，另验证联合回收预算和不可行退出码。
- moon info：通过，公开 API 文件已生成。
- moonpocket.ps1 --input examples/quiet.day --require-focus 400：通过，返回 470 专注分钟。
- 两份示例报告与 SVG：实际通过 CLI 生成，SVG XML 解析通过；碎片示例另经本地 Edge 无界面渲染，截图为 examples/fragmented-preview.png。
- 模块名改为 `code3055/moonpocket` 后，重复完成格式检查、检查、测试与构建；`moon package --list` 成功，`moon publish --dry-run` 完成归档与解包验证，服务器返回 `202 Accepted: Dry run completed successfully. No changes were made.`。该版工具在成功消息后仍报告退出码 1；尚未正式发布。

node tests/package.integration.mjs：发布包在独立临时目录完成检查、26 项核心测试、构建、13 项 CLI 测试、2 项求解器测试和保护日程示例。

验证范围为 JS 目标；此前 GitHub CI 已实际通过，新增发布包验证也已加入流程。未验证 native/wasm 目标；CLI 使用 JS 文件读写接口。建议仅计算时间收益，不评估安排重要性、能否移动或真实专注表现。
