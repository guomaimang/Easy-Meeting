# 项目开发规范

## 语言

所有交流、提交信息、代码注释、文档一律使用**简体中文**。

## 技术栈

查看 docs/tech-stack.md 了解全部技术栈

- 保证全局统一和复用性，如网络请求等

## 代码组织

- 按 feature/domain 用**文件夹**组织，禁止无关文件平铺同一目录
- 旧代码、旧接口被替换时**直接删除**，不保留死代码、不考虑向后兼容
- 应当考虑代码的复用。复用组件要完整迁移到新目录下。不要用更改引用目录的方式，防止架构污染

## 架构设计

- 遵循 SOLID 原则

## 工作流程（按顺序执行）

1. 阅读文档或者代码。
2. **文档先行**：明确要做什么, 先更新或新建相关文档。
3. **实现代码**：按文档设计编写代码
4. **E2E 测试**
5. **Lint 收尾**

## 文件行数

单文本文件 （无论文档还是代码）**不得超过 300 行**，超过必须拆分重构，比如创建文件夹并放入。

## 变更记录

每次修改在 `/changelog/` 下新建 `YYYY-MM-DD-<slug>.md`，简要记录变更内容。

## 文档同步

- 修改代码时保证下相关文档同步更新
- 文档与代码不一致视为任务未完成

## 日志

开发环境打印细粒度调试日志（每个功能模块的输入与输出），生产环境仅 INFO 及以上。开发时需要埋点。


# Rule

## Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
