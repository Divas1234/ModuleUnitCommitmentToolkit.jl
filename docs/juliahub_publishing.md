# JuliaHub / General Registry 发布说明

当前仓库根目录已经是标准 Julia 包结构：

```text
Project.toml
src/ModuleUnitCommitmentToolkit.jl
test/runtests.jl
LICENSE
```

包元数据如下：

```text
name   = ModuleUnitCommitmentToolkit
uuid   = a1b2c3d4-e5f6-7890-abcd-ef1234567890
version = 1.10.0
```

## 发布前检查

1. 在仓库根目录运行 `Pkg.test()`，确认所有测试通过。
2. 确认 `Project.toml` 的所有直接依赖都有带上界的 `[compat]` 条目。
3. 确认 `src/ModuleUnitCommitmentToolkit.jl` 与包名完全一致。
4. 确认顶层存在 OSI-approved license；本项目使用 MIT License。
5. 将当前提交推送到 GitHub，并创建 `v1.10.0` tag。

Julia General 的自动合并规则要求公共包仓库 URL 以包名结尾，即：

```text
https://github.com/Divas1234/ModuleUnitCommitmentToolkit.jl
```

当前远程仓库仍叫 `module_unitcommitment`。如果目标是公共 General registry，需先把
GitHub 仓库重命名为 `ModuleUnitCommitmentToolkit.jl`，随后更新本地 remote URL。若不重命名，
仍可尝试 JuliaHub/General 的手工注册，但可能无法通过自动合并检查。

## JuliaHub 注册流程

JuliaHub 当前通过 Registrator 创建 General registry 注册请求：

1. 登录 JuliaHub 的 Packages 页面并打开 Registrator。
2. 授权 Registrator 检查 GitHub 仓库的提交权限。
3. 填写包 URL、tag `v1.10.0` 和发布说明。
4. Registrator 创建 General registry pull request。
5. 等待 registry CI 和 General 维护者合并。
6. JuliaHub 会周期性同步已注册版本；同步完成后，用户即可使用：

   ```julia
   using Pkg
   Pkg.add("ModuleUnitCommitmentToolkit")
   ```

## GitHub 注册评论方式

如果使用 JuliaRegistrator GitHub App，也可以在包含 `Project.toml` 版本 `1.10.0` 的
提交或 pull request 中评论：

```text
@JuliaRegistrator register

Release notes:

- Unified Benchmark, Benders, and CCG solver entry point.
- PowerSystems IEEE case bridge and frequency/data-center examples.
- DataFrame-based input and result reports with CSV snapshots.
```

注册动作需要 GitHub/JuliaHub 登录权限，不能仅通过本地 `Pkg` 命令完成。
