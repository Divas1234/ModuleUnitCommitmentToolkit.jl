# 项目代码 Review

审查日期：2026-07-13

审查范围：`src/`、`tools/`、`gui/`、`examples/`、`docs/`、`test/` 及项目入口文件。

## 结论摘要

当前数据管线和基础模块测试结果稳定。项目原先的公共接口分成包级函数、脚本级函数
和旧式位置元组三层；本次已增加统一数据入口和统一算法入口，剩余重点是 GUI 安全边界、
输出路径解耦、位置元组兼容层治理以及算法级集成测试。此次也修正文档中会直接误导调用者
的三个示例问题，并将 GUI 默认监听地址限制为本机回环地址。

## 发现的问题

### P1：GUI 接口曾默认监听所有网卡，且提供配置写入与任务启动能力

`gui/server.py` 提供 `/api/config` 写入运行配置、`/api/run` 启动 Julia 任务和
`/api/run/cancel` 终止任务，但原先绑定 `0.0.0.0:8080`，也没有认证、CSRF 防护或
请求来源限制。若机器处于共享网络，其他主机可能调用这些本地管理接口。

本次已将默认监听改为 `127.0.0.1:8080`。远程绑定现在必须同时显式设置
`MODULE_UC_GUI_ALLOW_REMOTE=1`、Bearer token 和允许来源列表；服务还会校验请求体大小、
任务参数、来源、认证头和 API/运行频率，并返回基础安全响应头。若部署在公网，仍建议在
反向代理层补充 TLS、审计日志和更细粒度的账号权限控制。

### P1：算法入口曾经没有纳入同一个包级 API（已处理）

`ModuleUnitCommitmentToolkit` 主要暴露数据读取、桥接和基础模型函数；benchmark、
Benders、CCG 入口仍需手工 `include("tools/...")`。这会造成：

- 使用 `using ModuleUnitCommitmentToolkit` 的用户无法直接发现三种算法；
- 脚本依赖 include 顺序和当前工作目录；
- 算法接口没有统一的输入与结果类型。

本次新增 `ModuleUnitCommitmentToolkit.solve_uc` 统一入口，使用 `algorithm` 指示参数选择
`benchmark`、`benders` 或 `ccg`，使用 `input` 指示 Excel、PowerSystems 原生系统或
PowerSystems CSV 扩展数据，并用 `calibration` 集中设置运行期标定参数。算法实现仍按需
惰性加载，避免仅导入包时启动求解器或产生输出副作用；旧的 `tools/` 函数保留为兼容层。

### P1：Benders `main` 返回位置元组，维护成本和错位风险高

`tools/benders/setup.jl:33` 的 `main` 返回 20 个位置值，调用方需要手工记住
`NB, NG, NL, ND, NS, NT, NC, ND2` 的顺序；Benders、benchmark 和示例文件各自
重复解构。任何字段增删都会造成静默错位，且 Julia 不会给出字段名提示。

当前已由 `BendersSetup` 提供命名字段访问，并保留只读兼容迭代器支持旧的 20 项解构。
新增算法调用应使用 `UCSolveRequest`/`UCSolveResult`；后续可在迁移完成后移除兼容迭代器。

### P2：原有 PowerSystems 指南的可复制示例与真实签名不一致

审查时发现并已修正：

- Extensive-form 示例缺少 `solve_benchmark_uc_powersystems` 的闭合括号；
- CCG 示例传入了不存在的 `data` 位置参数和 `initial_scenarios` 关键字；
- Benders 示例把 `winds.scenarios_nums`（场景数）传给了 `NW`（风机数）。

修正位置：[`powersystems_algorithms_guide.md`](powersystems_algorithms_guide.md) 和
[`powersystems_example.jl`](powersystems_example.jl)。

### P2：输出目录依赖 `pwd()`，库函数从任意目录调用时结果位置不稳定（已处理）

原有 `src/unit_commitment/utilities/export_results.jl` 的一个导出函数默认输出目录以当前
工作目录为基准。现在默认输出根目录为项目根目录下的 `output/`，也可通过
`MODULE_UC_OUTPUT_DIR`、统一入口的 `output_dir` 或导出函数参数显式覆盖；算法运行目录和
调度导出均复用这套解析逻辑。

调用层应显式设置 `MODULE_UC_OUTPUT_DIR`，或直接使用统一入口的 `output_dir` 关键字参数。
benchmark 和 CCG 的文件输出已通过同一套输出根目录解析函数统一；Benders 当前以
内存结果为主，统一结果对象会返回配置的 `output_dir`，但暂不自动导出调度文件。

### P2：算法级和 GUI 级集成测试不足

当前轻量测试覆盖数据读取、PowerSystems 桥接、模型工具、DRO 辅助逻辑、统一入口的
路由/标定行为；CI 已加入一场景 benchmark/Benders/CCG smoke test 和 GUI 请求校验测试。
完整算法质量比较、任务互斥、取消和超时行为仍应持续扩展。建议补充：

1. Benders 结果与 extensive-form 目标值的容差比较；
2. CCG 最大迭代和无可行解分支；
3. GUI API 的任务并发、取消和超时行为。

## 已执行验证

```text
Julia 1.12.6
test/runtests.jl: 236 passed, 236 total
test/fast_interface.jl: 12 passed, 12 total
test/smoke_algorithms.jl: 7 passed, 7 total
test/test_gui_security.py: 4 passed, 4 total
项目下 222 个 Julia 文件：语法解析通过
```

还应注意：项目 `Project.toml` 与当前 Manifest 存在依赖版本漂移提示，正式发布前应
重新 resolve/instantiate 并锁定可复现环境；这不是本次文档接口修正的阻断项。

## 建议优先级

1. 已完成：统一命名输入/结果类型，Benders 位置元组进入兼容迁移期。
2. 已完成：三算法 smoke test 纳入 CI，并保留路由和数据入口快速测试。
3. 已完成：输出根目录显式化，库函数默认不再依赖调用者 `pwd()`。
4. 已完成基础防护：GUI 默认仅本机监听；远程部署必须先配置认证和来源限制。
