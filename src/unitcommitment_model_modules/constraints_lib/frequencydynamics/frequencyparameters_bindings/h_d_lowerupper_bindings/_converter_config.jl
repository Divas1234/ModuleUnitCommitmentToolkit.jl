function converter_formming_configuations()
    # Define the converter configurations
    converter_config = Dict(
        "VSM" => Dict(
            "controller" => "VSM",
            "control_parameters" => Dict(
                "inertia" => 2,  # VSM inertia coefficient
                "damping" => 0.5,  # VSM damping coefficient
                "time_constant" => 0.05,  # Unified time constant
            ),
        ),
        "Droop" => Dict(
            "controller" => "P-Q",
            "control_parameters" => Dict(
                "droop" => 0.05,  # Droop coefficient
                "time_constant" => 0.01,  # Unified time constant
            ),
        ),
    )

    return converter_config
end
