# 聚类 PCM 合并主分支说明

## 建议作为新增文件合并的目录

```text
src/unit_commitment/clustered_pcm/
├── clustered_pcm.jl      # src 统一入口
└── disaggregation.jl     # 驻留流、路径和物理解群

tools/pcm/clustered_pcm/
├── clustered_pcm.jl      # PCM 聚类统一入口
├── adapter.jl            # 旧 PCM 接口适配
├── master.jl             # 聚类主问题
└── network_dispatch.jl   # 单机网络再调度

tools/pcm/main.jl                # 三种方法的统一入口
```

测试文件也都是新增文件：

```text
test/test_clustered_disaggregation.jl
test/test_clustered_pcm_adapter.jl
test/test_clustered_pcm_master.jl
```

## 主分支最小接入点

若允许修改原 `period_scuc.jl`，只需要在其依赖区增加：

```julia
include("clustered_pcm/clustered_pcm.jl")
```

然后在原单机 SCUC 建模前调用 `solve_true_clustered_pcm_window`。本分支的
`period_scuc.jl` 已给出完整参考实现和失败回退逻辑。

若希望主分支原 PCM 文件完全不变，可以运行新增启动器：

```powershell
$env:PCM_METHOD='clustered_pcm'
julia --project=. tools/pcm/main.jl
```

需要注意：统一入口仍会加载 `standard/pcm_main.jl` 和 `standard/period_scuc.jl`；
因此“仅复制新增文件”适用于主分支已经具备上述单一 include/调用钩子的情况。

## src 与 tools 的边界

- `src/unit_commitment/clustered_pcm` 不依赖 PCM 文件布局，保存可复用算法。
- `tools/pcm/clustered_pcm` 允许依赖旧 PCM 数据结构，负责工程编排和兼容输出。
- 输入 Excel、仿真输出和对比报告不放入算法目录。

这个边界可以避免将来为了修改 PCM 输出格式而改动驻留流核心算法。
