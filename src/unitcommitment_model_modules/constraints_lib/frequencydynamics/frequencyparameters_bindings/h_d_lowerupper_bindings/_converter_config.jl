function converter_formming_configuations()
	# Define the converter configurations
	converter_config = Dict(
		"VSM" => Dict(
			"controller" => "VSM",
			"control_parameters" => Dict(
				"inertia" => 2,  # Set the VSM inertia coefficient.
				"damping" => 0.5,  # Set the VSM damping coefficient.
				"time_constant" => 0.05  # Use a consistent time constant.
			)
		),
		"Droop" => Dict(
			"controller" => "P-Q",
			"control_parameters" => Dict(
				"droop" => 0.05,  # Set the droop coefficient.
				"time_constant" => 0.01  # Use a consistent time constant.
			)
		)
	)

	return converter_config
end
