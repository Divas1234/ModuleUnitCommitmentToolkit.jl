@testset "H-D frequency security region (hd_estimation)" begin
    @testset "SFR physics single source of truth" begin
        # RoCoF inertia floor: H_min = f0 * ΔP / (2 * RoCoF)
        @test isapprox(hd_rocof_min_inertia(0.1, 0.5; f0 = 50.0), 5.0; atol = 1e-12)
        @test isapprox(hd_rocof_min_inertia_axis(0.1, 0.5, 2.0; f0 = 50.0), 3.0; atol = 1e-12)
        @test hd_rocof_min_inertia_axis(0.1, 0.5, 8.0; f0 = 50.0) == 0.0
        @test_throws ArgumentError hd_rocof_min_inertia(0.1, 0.0)

        # QSS minimum damping: D_min = max(0, f0 * ΔP / Δf_qss - K)
        @test isapprox(hd_qss_min_damping(0.2, 0.5, 15.0; f0 = 50.0), 5.0; atol = 1e-12)
        @test hd_qss_min_damping(0.1, 0.5, 20.0; f0 = 50.0) == 0.0

        # Under-damped window and positive nadir time
        h_lo, h_hi = hd_sfr_underdamped_window(1.0, 20.0, 8.0, 0.25)
        @test 0.0 < h_lo < h_hi
        h_mid = 0.5 * (h_lo + h_hi)
        ζ, ωn = hd_sfr_damping_parameters(h_mid, 1.0, 20.0, 8.0, 0.25)
        @test 0.0 < ζ < 1.0
        @test ωn > 0.0
        t_n = hd_sfr_nadir_time(h_mid, 1.0, 20.0, 8.0, 0.25)
        @test isfinite(t_n) && t_n > 0.0

        # Higher inertia or higher damping reduces nadir deviation
        nadir_low_H = hd_sfr_nadir_pu(3.0, 1.0, 20.0, 8.0, 0.25, 0.1)
        nadir_high_H = hd_sfr_nadir_pu(8.0, 1.0, 20.0, 8.0, 0.25, 0.1)
        nadir_high_D = hd_sfr_nadir_pu(3.0, 4.0, 20.0, 8.0, 0.25, 0.1)
        @test isfinite(nadir_low_H) && isfinite(nadir_high_H) && isfinite(nadir_high_D)
        @test nadir_high_H < nadir_low_H
        @test nadir_high_D < nadir_low_H

        # Over-damped regime falls back smoothly to QSS deviation
        nadir_over = hd_sfr_nadir_pu(h_hi * 2.0, 1.0, 20.0, 8.0, 0.25, 0.1; include_overdamped = true)
        @test isapprox(nadir_over, 0.1 / 21.0; atol = 1e-12)
        @test isnan(hd_sfr_nadir_pu(h_hi * 2.0, 1.0, 20.0, 8.0, 0.25, 0.1; include_overdamped = false))
    end

    @testset "H-D security region assessment & converter support" begin
        params_sync = HDFrequencyParameters(
            f0_hz = 50.0,
            rocof_limit_hz_per_s = 1.0,
            nadir_limit_hz = 0.5,
            qss_limit_hz = 0.5,
            delta_p_pu = 0.15,
            droop_gain_K = 16.0,
            turbine_fraction_FH = 0.25,
            reheat_time_T = 8.0,
            damping_min = 0.0,
            damping_max = 10.0,
            damping_points = 41,
        )
        res_sync = assess_hd_frequency_region(params_sync)
        @test !isempty(res_sync.feasible_indices)
        @test !isempty(res_sync.vertices)
        @test res_sync.rocof_min_inertia_sync > 0.0
        @test res_sync.min_inertia_demand >= res_sync.rocof_min_inertia_sync - 1e-9
        @test res_sync.min_damping_demand >= res_sync.qss_min_damping_sync - 1e-9

        # Monotonicity: required inertia is non-increasing with damping
        h_feas = res_sync.required_inertia[res_sync.feasible_indices]
        @test all(diff(h_feas) .<= 1e-4)

        # Adding VSM/converter support lowers required synchronous inertia
        params_vsm = HDFrequencyParameters(
            f0_hz = 50.0,
            rocof_limit_hz_per_s = 1.0,
            nadir_limit_hz = 0.5,
            qss_limit_hz = 0.5,
            delta_p_pu = 0.15,
            droop_gain_K = 16.0,
            turbine_fraction_FH = 0.25,
            reheat_time_T = 8.0,
            H_vsm = 1.5,
            D_vsm = 1.0,
            K_conv = 2.0,
            damping_min = 0.0,
            damping_max = 10.0,
            damping_points = 41,
        )
        res_vsm = assess_hd_frequency_region(params_vsm)
        @test res_vsm.rocof_min_inertia_sync < res_sync.rocof_min_inertia_sync
        @test res_vsm.min_inertia_demand <= res_sync.min_inertia_demand

        # DataFrame summary reporting
        summary_df = hd_region_summary_dataframe(res_sync)
        @test size(summary_df, 2) == 2
        @test size(summary_df, 1) >= 10
    end

    @testset "Conservative linear cut generation (zero violation)" begin
        params = HDFrequencyParameters(
            f0_hz = 50.0,
            rocof_limit_hz_per_s = 2.0,
            nadir_limit_hz = 0.5,
            qss_limit_hz = 0.5,
            delta_p_pu = 0.15,
            droop_gain_K = 16.0,
            turbine_fraction_FH = 0.25,
            reheat_time_T = 8.0,
            damping_min = 0.0,
            damping_max = 10.0,
            damping_points = 41,
        )
        res = assess_hd_frequency_region(params)
        cuts = build_hd_linear_cuts(res; max_cuts = 6)

        @test cuts.max_violation_s <= 1e-8
        @test all(cuts.beta .>= 0.0)
        @test length(cuts.alpha) <= 6
        @test isfinite(cuts.H_max_sync) && cuts.H_max_sync > cuts.H_min_sync
        @test isfinite(cuts.D_max_sync) && cuts.D_max_sync > cuts.D_min_sync
        @test all(cuts.beta_upper .>= 0.0)

        # Every feasible point on the true H-D boundary must be conservatively bounded
        for idx in res.feasible_indices
            d = res.damping_grid[idx]
            h_true = res.required_inertia[idx]
            h_env = cuts.H_min_sync
            for m in eachindex(cuts.alpha)
                h_env = max(h_env, cuts.alpha[m] - cuts.beta[m] * d)
            end
            @test h_env >= h_true - 1e-6
            # And any point sitting on the linear envelope satisfies the exact physical nadir limit
            nadir_hz = params.f0_hz * hd_effective_nadir_pu(
                h_env,
                d,
                params.droop_gain_K,
                params.reheat_time_T,
                params.turbine_fraction_FH,
                params.delta_p_pu,
            )
            @test nadir_hz <= params.nadir_limit_hz + 1e-4
        end

        cuts_df = hd_cuts_dataframe(cuts)
        @test size(cuts_df, 1) == length(cuts.alpha) + length(cuts.alpha_upper)
    end

    @testset "UC adapter & add_frequency_constraints! mode routing" begin
        UnitsFreqParam, WindsFreqParam, storage_data, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, data_center_data =
            readxlssheet()
        config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, data_centers =
            forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, storage_data, data_center_data)
        winds, NW = genscenario(WindsFreqParam, 1; scenario_limit = 2)

        hd_params = extract_uc_hd_parameters(units, winds, maximum(units.p_max))
        @test hd_params.droop_gain_K > 0.0
        @test 0.0 <= hd_params.turbine_fraction_FH < 1.0
        @test hd_params.reheat_time_T > 0.0

        cfg_freq = config(
            config_param.is_network_con,
            config_param.is_thermal_unit_con,
            config_param.is_wind_unit_con,
            config_param.is_system_con,
            config_param.is_piecewise_linear,
            config_param.num_segments,
            config_param.alpha,
            config_param.beta,
            config_param.coal_price,
            config_param.is_active_load,
            config_param.is_wind_integration,
            config_param.load_cutting_coefficient,
            config_param.wind_cutting_coefficient,
            config_param.max_iterations,
            config_param.calculation_precision,
            config_param.consider_data_center,
            1, # consider_frequency_control = 1
            config_param.consider_bess,
            config_param.consider_multi_cuts,
        )

        # Route via FREQUENCY_MODEL_MODE = "hd_region"
        withenv("FREQUENCY_MODEL_MODE" => "hd_region") do
            @test frequency_model_mode() === :hd_region
            m = build_uc_model(; silent = true)
            @variable(m, x[1:NG, 1:NT], Bin)
            @variable(m, sr⁺[1:(2 * NG), 1:NT] >= 0)
            out = add_frequency_constraints!(m, NT, NG, NC, 2, units, psses, cfg_freq, maximum(units.p_max); winds = winds)
            @test out.mode === :hd_region
            @test out.region isa HDFrequencyRegionResult
            @test out.cuts isa HDLinearCutSet
            @test out.rocof !== nothing
            @test out.inertia_upper !== nothing
            @test out.damping_upper !== nothing
        end

        # Route via FREQUENCY_MODEL_MODE = "hybrid"
        withenv("FREQUENCY_MODEL_MODE" => "hybrid") do
            @test frequency_model_mode() === :hybrid
            m = build_uc_model(; silent = true)
            @variable(m, x[1:NG, 1:NT], Bin)
            @variable(m, sr⁺[1:(2 * NG), 1:NT] >= 0)
            out = add_frequency_constraints!(m, NT, NG, NC, 2, units, psses, cfg_freq, maximum(units.p_max); winds = winds)
            @test out.mode === :hybrid
            @test out.legacy.mode === :legacy
            @test out.hd.mode === :hd_region
        end
    end
end
