@testset "PCM clustered optimization adapter" begin
    units=(index = [1, 2], locatebus = [1, 1], p_min = [0.0, 0.0], p_max = [60.0, 60.0], ramp_up = [100.0, 100.0], ramp_down = [100.0, 100.0],
        shut_up = [60.0, 60.0], shut_down = [60.0, 60.0], min_shutup_time = [2.0, 2.0], min_shutdown_time = [2.0, 2.0], x_0 = [0.0, 0.0],
        t_0 = [0.0, 0.0], t_1 = [0.0, 0.0], p_0 = [0.0, 0.0], coffi_a = [0.0, 0.0], coffi_b = [10.0, 10.0], coffi_c = [1.0, 1.0])
    clusters=build_pcm_clusters(units)
    @test length(clusters)==1
    @test clusters[1].unit_indices==[1, 2]

    results=Dict{String, Array{Float64}}("x₀"=>[1.0 1.0; 0.0 1.0], "u₀"=>[1.0 0.0; 0.0 1.0], "v₀"=>zeros(2, 2), "p₀"=>[40.0 50.0; 0.0 40.0],
        "seq_sr⁺"=>zeros(2, 2), "seq_sr⁻"=>zeros(2, 2), "pᵨ"=>zeros(1, 2), "pᵩ"=>zeros(1, 2))
    loads=(locatebus = [1], load_curve = [40.0 90.0])
    winds=(index = Int[], locatebus = Int[], p_max = Float64[], scenarios_curve = zeros(1, 2))
    lines=(p_min = Float64[], p_max = Float64[])
    config=(is_NetWorkCon = 0,)
    report=apply_clustered_pcm_optimization!(results, units, loads, winds, lines, config, 1, 0)
    @test report.feasible
    @test report.stage==:complete
    @test results["cluster_ids"]==[1.0, 1.0]
    @test results["cluster_disaggregation_feasible"]==ones(1, 1)
    @test vec(sum(results["p₀"]; dims = 1))≈[40.0, 90.0]
end

@testset "clustered PCM Excel input" begin
    source=XLSX.readxlsx(joinpath(PROJECT_ROOT, "data", "data_118.xlsx"))
    clustered=XLSX.readxlsx(joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm.xlsx"))
    @test size(clustered["units_data"][:], 1)-1==2*(size(source["units_data"][:], 1)-1)
    @test size(clustered["units_frequencyparam"][:], 1)-1==108
    @test size(clustered["winds_frequencyparam"][:], 1)-1==20
    @test clustered["load_curve"]["B2"][]≈2*source["load_curve"]["B2"][]
    @test clustered["branch_data"]["E2"][]≈2*source["branch_data"]["E2"][]
end

@testset "10x homogeneous clustered PCM Excel input" begin
    source=XLSX.readxlsx(joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm.xlsx"))
    expanded=XLSX.readxlsx(joinpath(PROJECT_ROOT, "data", "data_118_clustered_pcm_10x.xlsx"))
    @test size(expanded["units_data"][:], 1)-1==10*(size(source["units_data"][:], 1)-1)==1080
    @test size(expanded["units_cost"][:], 1)-1==1080
    @test size(expanded["units_frequencyparam"][:], 1)-1==1080
    @test expanded["units_data"]["A1081"][]==1080
    @test expanded["units_frequencyparam"]["A1081"][]==1080
    @test expanded["load_curve"]["B2"][]≈10*source["load_curve"]["B2"][]
    @test expanded["branch_data"]["E2"][]≈10*source["branch_data"]["E2"][]
end
