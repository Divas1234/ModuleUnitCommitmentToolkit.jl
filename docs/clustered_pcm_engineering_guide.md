# Clustered PCM 工程导读

## 阅读顺序

1. `tools/pcm/standard/pcm_main.jl`：读取数据、固定风电种子、执行滚动窗口。
2. `tools/pcm/standard/period_scuc.jl`：选择聚类路径或原单机 SCUC。
3. `tools/pcm/clustered_pcm/master.jl`：建立同质簇和虚拟机组主问题。
4. `src/unit_commitment/clustered_pcm/disaggregation.jl`：驻留流、路径匹配和网络解群。
5. `tools/pcm/clustered_pcm/network_dispatch.jl`：固定单机启停路径后的联合网络调度模型。

## 调用链

```text
Excel + 固定风电种子
  → 同质机组等价类
  → 聚类主问题 U/Y/Z/P/R
  → 连续驻留流检查
  → 匿名路径映射到物理机组
  → 单机出力及 PTDF 网络解群
  → 可行则输出；冲突则反馈线路；仍失败则回退单机 SCUC
```

## 为什么必须严格同质

`U[g,t]` 表示簇内在线台数，不指向某一台机组。只有簇内成员在节点、容量、爬坡、最小启停时间、成本和初始状态上可互换时，一个计数状态才具有明确的物理含义。

因此当前实现不会仅因“位于同一个节点”就聚合机组。扩展 Excel 中的机组是成对复制的，108 台物理机组可形成 54 个虚拟机组。

## 主问题变量

- `U[g,t]`：在线台数；
- `Y[g,t]`：启动台数；
- `Z[g,t]`：停机台数；
- `P[g,t]`：簇总出力；
- `R[g,t]`、`Rdown[g,t]`：上下备用；
- `Q[g,t,k]`：三段线性燃料成本的分段出力。

状态计数满足：

```text
U[g,t] - U[g,t-1] = Y[g,t] - Z[g,t]
```

计数整数变量替代逐台二进制变量，是聚类模型减少组合规模的核心。

## 连续驻留检查

聚合最小启停约束只能约束台数，不能说明具体哪台机组切换状态。驻留流层为每台匿名机组维护开/停状态及其持续时间，只允许达到 `ON_MATURE` 或 `OFF_MATURE` 的路径发生合法切换。

如果计数轨迹无法分解为完整整数路径，聚类结果不会进入输出阶段。

## 网络为什么在第二阶段处理

初始聚类主问题不放完整线路集合，以保留规模优势。路径映射完成后，物理出力通过 PTDF 网络检查；越限线路才反馈到主问题。`tools/pcm/clustered_pcm/network_dispatch.jl` 封装了固定 `U/Y/Z` 后联合调整热机、水电、备用和弃风的第二阶段模型。

任何需要负荷损失才能成立的解都不应被视为成功的物理解群。

## 公平对比

```powershell
$env:PCM_INPUT_XLSX='data/data_118_clustered_pcm.xlsx'
$env:PCM_RANDOM_SEED='20260809'
$env:PCM_INTERVALS='1'
$env:PCM_WINDOW_HOURS='24'
$env:PCM_USE_CLUSTERED_UC='true'
```

将最后一项改为 `false` 即运行单机 PCM。默认随机种子也是 `20260809`，因此独立进程仍使用相同风电轨迹。

## 结果边界

“驻留可解群”只证明启停计数能映射到物理机组；“网络可解群”进一步证明出力和线路可行；两者都不自动保证聚类成本等于单机最优成本。当前仍需通过冲突簇局部拆分改善水电利用、弃风和经济精度。
