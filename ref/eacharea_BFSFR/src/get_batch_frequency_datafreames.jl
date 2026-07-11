using Plots
include("batch_dataclean_utils.jl")

function get_sumstructed_frequencyderivation_data(selected_file_name, distribution_type::String)
    all_folder_dataframes = get_structed_frequencyderivatoins_data(distribution_type);

    sum_frequencyderivatoins_data = get_combined_frequencyderivatoins_data(all_folder_dataframes, selected_file_name, distribution_type);

    names(sum_frequencyderivatoins_data)
    # sum_frequencyderivatoins_data[!,"folder_Gaussian(0.0037)"]
    return sum_frequencyderivatoins_data
end
# Plots.plot(sum_frequencyderivatoins_data[!,"folder_Gaussian(0.002)"], label="Gaussian(0.002)")
# Plots.plot!(sum_frequencyderivatoins_data[!,"folder_Gaussian(0.0018)"], label="Gaussian(0.0018)")
# Plots.plot!(sum_frequencyderivatoins_data[!,"folder_Gaussian(0.005)"], label="Gaussian(0.005)")
