"""PCM Excel input adapter bridging `main`'s 9-tuple `readxlssheet()` / 13-tuple `forminputdata()`
to PCM's rolling-horizon interface (including optional empty hydro tuple and network switch)."""

function load_pcm_excel_data(; data_file::Union{Nothing, AbstractString} = nothing)
    net_flag = get(ENV, "PCM_NETWORK_CONSTRAINTS", "0")
    raw = withenv("MODEL_IS_NETWORK_CON" => net_flag) do
        data_file === nothing ? readxlssheet() : readxlssheet(String(data_file))
    end
    UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data = raw[1:9]

    config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras =
        withenv("MODEL_IS_NETWORK_CON" => net_flag) do
            forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, Datacentra_Data)
        end

    NH = 0
    hydros = (
        index = Int64[],
        locatebus = Int64[],
        p_min = Float64[],
        p_max = Float64[],
        inflow = zeros(Float64, 0, NT),
    )
    return (
        config_param = config_param,
        units = units,
        lines = lines,
        loads = loads,
        stroges = stroges,
        NB = NB,
        NG = NG,
        NL = NL,
        ND = ND,
        NT = NT,
        NC = NC,
        ND2 = ND2,
        NH = NH,
        DataCentras = DataCentras,
        hydros = hydros,
        WindsFreqParam = WindsFreqParam,
    )
end
