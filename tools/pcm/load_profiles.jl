# PCM 基准实验负荷曲线变换；所有变体保持总电量不变，确保成本比较公平。
if !isdefined(@__MODULE__, :_PCM_LOAD_PROFILES_INCLUDED)
    const _PCM_LOAD_PROFILES_INCLUDED = true

    function _rescale_energy!(curve, target_energy)
        current_energy=sum(curve)
        current_energy>0 && (curve .*= target_energy/current_energy)
        return curve
    end

    function apply_pcm_load_profile!(loads, profile::AbstractString)
        mode=lowercase(strip(profile))
        mode in ("", "baseline", "original") && return loads

        original=copy(loads.load_curve)
        target_energy=sum(original)
        hours=size(original, 2)

        if mode == "smooth"
            smoothed=similar(original)
            for t ∈ 1:hours
                window=max(1, t - 2):min(hours, t + 2)
                smoothed[:, t].=vec(mean(original[:, window]; dims = 2))
            end
            loads.load_curve=_rescale_energy!(smoothed, target_energy)
        elseif mode in ("extreme_ramp", "ramp")
            # 每 4 小时在低谷/尖峰间切换，叠加确定性脉冲，形成频繁极端净负荷爬坡。
            factors=[isodd(div(t-1, 4)) ? 1.30 : 0.70 for t ∈ 1:hours]
            for t ∈ 1:hours
                t%12==0 && (factors[t]*=1.15)
            end
            ramped=original .* reshape(factors, 1, :)
            loads.load_curve=_rescale_energy!(ramped, target_energy)
        else
            throw(ArgumentError("Unsupported PCM_LOAD_PROFILE='$profile'. Use baseline, smooth, or extreme_ramp."))
        end
        return loads
    end
end
