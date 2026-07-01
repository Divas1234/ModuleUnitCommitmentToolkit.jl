using DataFrames
using CSV

function get_combined_frequencyderivatoins_data(all_folder_dataframes, file_name, distribution_type::String = "Gaussian")
    sum_frequencyderivatoins_data = DataFrame()

    for (id, data) in all_folder_dataframes
        each_case_datafile = all_folder_dataframes[id][file_name]
        sum_frequencyderivatoins_data[!, id] = each_case_datafile[!, :bfsfr_data]
    end
    return sum_frequencyderivatoins_data
end

function get_structed_frequencyderivatoins_data(distribution_type::String)
    current_folders_lists = get_filtered_folders([".vscode"], distribution_type)

    each_folder_dataframes = Dict{String, Dict{String, DataFrame}}()
    abbreviated_folder_names = basename.(current_folders_lists)
    num_folders = length(abbreviated_folder_names)
    for index in 1:num_folders
        name = string("folder_", abbreviated_folder_names[index])
        each_folder_dataframes[name] = get_batch_frequency_dataframes(current_folders_lists[index])
    end

    # @show keys(each_folder_dataframes)

    return each_folder_dataframes
end

function get_filtered_folders(exclude_patterns::Vector{String}, distribution_type::String)
    # distribution_type = "Gaussian"
    if occursin("Gaussian", distribution_type)
        dir_path = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\Gaussian(various_uncertain_variability_features)"
    elseif occursin("Weibull", distribution_type)
        dir_path = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\Weibull(various_uncertain_variability_features)"
    else
        dir_path = "D:\\GithubClonefiles\\RFCUC\\RfcucCaseStudies\\eacharea_BFSFR\\res\\fcr_bindings"
    end
    folders = filter(isdir, readdir(dir_path, join = true))
    return filter(folder -> all(p -> !occursin(p, folder), exclude_patterns), folders)
end

function get_batch_frequency_dataframes(each_folder)
    csv_files = filter(f -> endswith(f, ".csv"), readdir(each_folder, join = true))
    each_folder_dataframes = Dict{String, DataFrame}()

    for csv_file in csv_files
        df = DataFrame(CSV.File(csv_file))
        each_folder_dataframes[basename(csv_file)] = df
    end

    return each_folder_dataframes
end
