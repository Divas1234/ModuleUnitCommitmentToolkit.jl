# Extended residence-age and output-state network-flow hull builders for clustered PCM.
if !isdefined(@__MODULE__, :_PCM_RESIDENCE_HULL_INCLUDED)
	const _PCM_RESIDENCE_HULL_INCLUDED = true
	using JuMP

	_clustered_pcm_up_ramp_limit(previous_online, startups, ramp_up, startup_ramp) = ramp_up * previous_online + startup_ramp * startups
	_clustered_pcm_down_ramp_limit(current_online, shutdowns, ramp_down, shutdown_ramp) = ramp_down * current_online + shutdown_ramp * shutdowns

	"""
	在聚类主问题中建立驻留年龄与出力联合的扩展网络流。

	每个物理机组在 ON(1)...ON(L+) / OFF(1)...OFF(D+) 状态间流动；
	在线弧同时携带弧起点出力和弧终点出力，因此普通爬坡、启动爬坡和
	停机爬坡都在单条状态弧上约束。对同质机组，整数状态流可分解成物理
	路径，连续出力流也可沿相同路径分解，避免簇总爬坡约束的假可行。
	"""
	function add_cluster_residence_power_flow_hull!(m, clusters, units, NT, U, Y, Z, P;
			tolerance=1e-7)
		state_refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id
			L=max(1, c.min_up)
			D=max(1, c.min_down)
			on=@variable(m, [1:L, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_on_age")
			off=@variable(m, [1:D, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_off_age")
			onflow=@variable(m, [1:L, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_on_flow")
			offflow=@variable(m, [1:D, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_off_flow")
			startup=@variable(m, [1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_startup_flow")
			shutdown=@variable(m, [1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_shutdown_flow")
			pon=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_on_power")
			pfrom=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_arc_power_from")
			pto=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_arc_power_to")
			pstartup=@variable(m, [1:NT], lower_bound=0, base_name="cluster_$(g)_startup_power")
			pshutdown=@variable(m, [1:NT], lower_bound=0, base_name="cluster_$(g)_shutdown_power")

			ids=c.unit_indices
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			initial_on=zeros(Int, L); initial_off=zeros(Int, D); initial_power=zeros(Float64, L)
			for i ∈ ids
				if units.x_0[i]>0.5
					raw=units.t_0[i]>0 ? round(Int, units.t_0[i]) : L
					a=clamp(raw, 1, L)
					initial_on[a]+=1
					initial_power[a]+=units.p_0[i]
				else
					raw=units.t_1[i]>0 ? round(Int, units.t_1[i]) : D
					initial_off[clamp(raw, 1, D)]+=1
				end
			end

			for t ∈ 1:NT
				for a ∈ (L>1 ? (1:L-1) : (1:0))
					source=t==1 ? initial_on[a] : on[a, t-1]
					@constraint(m, onflow[a, t]==source)
				end
				source_on_mature=t==1 ? initial_on[L] : on[L, t-1]
				@constraint(m, onflow[L, t]+shutdown[t]==source_on_mature)
				for a ∈ (D>1 ? (1:D-1) : (1:0))
					source=t==1 ? initial_off[a] : off[a, t-1]
					@constraint(m, offflow[a, t]==source)
				end
				source_off_mature=t==1 ? initial_off[D] : off[D, t-1]
				@constraint(m, offflow[D, t]+startup[t]==source_off_mature)

				@constraint(m, on[1, t]==startup[t]+(L==1 ? onflow[1, t] : 0))
				for a ∈ (L>2 ? (2:L-1) : (1:0))
					@constraint(m, on[a, t]==onflow[a-1, t])
				end
				L>1 && @constraint(m, on[L, t]==onflow[L-1, t]+onflow[L, t])
				@constraint(m, off[1, t]==shutdown[t]+(D==1 ? offflow[1, t] : 0))
				for a ∈ (D>2 ? (2:D-1) : (1:0))
					@constraint(m, off[a, t]==offflow[a-1, t])
				end
				D>1 && @constraint(m, off[D, t]==offflow[D-1, t]+offflow[D, t])

				@constraint(m, U[g, t]==sum(on[:, t]))
				@constraint(m, Y[g, t]==startup[t])
				@constraint(m, Z[g, t]==shutdown[t])
				@constraint(m, P[g, t]==sum(pon[:, t]))

				for a ∈ (L>1 ? (1:L-1) : (1:0))
					source_power=t==1 ? initial_power[a] : pon[a, t-1]
					@constraint(m, pfrom[a, t]==source_power)
				end
				source_mature_power=t==1 ? initial_power[L] : pon[L, t-1]
				@constraint(m, pfrom[L, t]+pshutdown[t]==source_mature_power)
				for a ∈ 1:L
					@constraint(m, pmin*onflow[a, t]<=pfrom[a, t])
					@constraint(m, pfrom[a, t]<=pmax*onflow[a, t])
					@constraint(m, pmin*onflow[a, t]<=pto[a, t])
					@constraint(m, pto[a, t]<=pmax*onflow[a, t])
					@constraint(m, pto[a, t]-pfrom[a, t]<=ru*onflow[a, t])
					@constraint(m, pfrom[a, t]-pto[a, t]<=rd*onflow[a, t])
				end
				@constraint(m, pmin*shutdown[t]<=pshutdown[t])
				@constraint(m, pshutdown[t]<=dr*shutdown[t])
				@constraint(m, pmin*startup[t]<=pstartup[t])
				@constraint(m, pstartup[t]<=sr*startup[t])
				@constraint(m, pon[1, t]==pstartup[t]+(L==1 ? pto[1, t] : 0))
				for a ∈ (L>2 ? (2:L-1) : (1:0))
					@constraint(m, pon[a, t]==pto[a-1, t])
				end
				L>1 && @constraint(m, pon[L, t]==pto[L-1, t]+pto[L, t])
			end
			state_refs[g]=(on=on, off=off, onflow=onflow, offflow=offflow,
				startup=startup, shutdown=shutdown, pon=pon, pfrom=pfrom, pto=pto)
		end
		state_refs
	end

	"""Add an integer output-state transition network sharing U/Y/Z/P."""
	function add_cluster_output_state_flow_hull!(m, clusters, units, NT, U, Y, Z, P;
			bins::Int=parse(Int, get(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")), tolerance=1e-7)
		bins=max(2, bins)
		refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id; ids=c.unit_indices
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			initial_levels=[units.p_0[i] for i ∈ ids if units.x_0[i]>0.5]
			levels=sort!(unique(vcat(collect(range(pmin, pmax; length=bins)), initial_levels)))
			K=length(levels)
			B=@variable(m, [1:K, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_output_state")
			A=@variable(m, [1:K, 1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_output_arc")
			SU=@variable(m, [1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_startup_output_arc")
			SD=@variable(m, [1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_shutdown_output_arc")
			initial=zeros(Int, K)
			for i ∈ ids
				if units.x_0[i]>0.5
					k=argmin(abs.(levels.-units.p_0[i]))
					initial[k]+=1
				end
			end
			for t ∈ 1:NT
				for k ∈ 1:K
					previous=t==1 ? initial[k] : B[k, t-1]
					@constraint(m, sum(A[k, l, t] for l ∈ 1:K)+SD[k, t]==previous)
					@constraint(m, sum(A[l, k, t] for l ∈ 1:K)+SU[k, t]==B[k, t])
					levels[k]>dr+tolerance && @constraint(m, SD[k, t]==0)
					levels[k]>sr+tolerance && @constraint(m, SU[k, t]==0)
				end
				for k ∈ 1:K, l ∈ 1:K
					(levels[l]-levels[k]>ru+tolerance || levels[k]-levels[l]>rd+tolerance) &&
						@constraint(m, A[k, l, t]==0)
				end
				@constraint(m, sum(B[:, t])==U[g, t])
				@constraint(m, sum(SU[:, t])==Y[g, t])
				@constraint(m, sum(SD[:, t])==Z[g, t])
				@constraint(m, P[g, t]==sum(levels[k]*B[k, t] for k ∈ 1:K))
			end
			refs[g]=(states=B, transitions=A, startup=SU, shutdown=SD, levels=levels)
		end
		refs
	end

	"""
	建立“驻留年龄 × 出力档位”乘积状态流。

	与两个独立边际网络不同，`ON[a,k,t]` 中的同一份机组计数同时携带
	开机年龄 `a` 和出力状态 `k`。普通转移弧只有在年龄演化正确且出力满足
	爬坡约束时才存在；启动仅从成熟 OFF 池进入 ON(1)，停机仅从成熟 ON
	状态进入 OFF(1)。因此任意整数流都能直接分解为满足驻留和爬坡的单机路径。
	"""
	function add_cluster_residence_output_product_hull!(m, clusters, units, NT, U, Y, Z, P;
			bins::Int=parse(Int, get(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")), tolerance=1e-7)
		refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id; ids=c.unit_indices; L=max(1,c.min_up); D=max(1,c.min_down)
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			initial_levels=[units.p_0[i] for i ∈ ids if units.x_0[i]>0.5]
			levels=sort!(unique(vcat(collect(range(pmin,pmax; length=max(2,bins))), initial_levels)))
			K=length(levels)
			ON=@variable(m,[1:L,1:K,1:NT],lower_bound=0,integer=true,base_name="cluster_$(g)_age_output")
			OFF=@variable(m,[1:D,1:NT],lower_bound=0,integer=true,base_name="cluster_$(g)_off_age_product")
			F=@variable(m,[1:L,1:K,1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_age_output_arc")
			OF=@variable(m,[1:D,1:NT],lower_bound=0,base_name="cluster_$(g)_off_arc_product")
			SU=@variable(m,[1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_startup_product")
			SD=@variable(m,[1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_shutdown_product")
			initial_on=zeros(Int,L,K); initial_off=zeros(Int,D)
			for i ∈ ids
				if units.x_0[i]>0.5
					a=clamp(units.t_0[i]>0 ? round(Int,units.t_0[i]) : L,1,L)
					k=argmin(abs.(levels.-units.p_0[i])); initial_on[a,k]+=1
				else
					d=clamp(units.t_1[i]>0 ? round(Int,units.t_1[i]) : D,1,D); initial_off[d]+=1
				end
			end
			for t ∈ 1:NT
				for a ∈ 1:L, k ∈ 1:K
					source=t==1 ? initial_on[a,k] : ON[a,k,t-1]
					@constraint(m,sum(F[a,k,l,t] for l ∈ 1:K)+(a==L ? SD[k,t] : 0)==source)
					(a<L || levels[k]<=dr+tolerance) || @constraint(m,SD[k,t]==0)
					for l ∈ 1:K
						(levels[l]-levels[k]>ru+tolerance || levels[k]-levels[l]>rd+tolerance) &&
							@constraint(m,F[a,k,l,t]==0)
					end
				end
				for a ∈ 1:L, l ∈ 1:K
					incoming=a==1 ? SU[l,t] : sum(F[a-1,k,l,t] for k ∈ 1:K)
					a==L && (incoming += sum(F[L,k,l,t] for k ∈ 1:K))
					@constraint(m,ON[a,l,t]==incoming)
				end
				for k ∈ 1:K
					levels[k]>sr+tolerance && @constraint(m,SU[k,t]==0)
				end
				for d ∈ 1:D
					source=t==1 ? initial_off[d] : OFF[d,t-1]
					@constraint(m,OF[d,t]+(d==D ? sum(SU[:,t]) : 0)==source)
				end
				@constraint(m,OFF[1,t]==sum(SD[:,t])+(D==1 ? OF[1,t] : 0))
				for d ∈ 2:D-1; @constraint(m,OFF[d,t]==OF[d-1,t]); end
				D>1 && @constraint(m,OFF[D,t]==OF[D-1,t]+OF[D,t])
				@constraint(m,U[g,t]==sum(ON[:,:,t]))
				@constraint(m,Y[g,t]==sum(SU[:,t]))
				@constraint(m,Z[g,t]==sum(SD[:,t]))
				@constraint(m,P[g,t]==sum(levels[k]*ON[a,k,t] for a ∈ 1:L,k ∈ 1:K))
			end
			refs[g]=(on=ON,off=OFF,transitions=F,startup=SU,shutdown=SD,levels=levels)
		end
		refs
	end
end
