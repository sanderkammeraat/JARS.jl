
#Input/Output
module JIO
using JLD2
using HDF5

function load_file(file_location)

    file = jldopen(file_location, "r",iotype=IOStream)
    return file
end

function initialize_file(save_path; mode::Symbol=:new)

    mkpath(dirname(save_path))
    if mode === :overwrite
        return h5open(save_path, "w")
    elseif mode === :append || !isfile(save_path)
        return h5open(save_path, "cw")
    elseif mode === :new
        error("File $save_path already exists; use mode=:append or :overwrite.")
    else
        throw(ArgumentError("mode must be :new, :append or :overwrite, got :$mode"))
    end
end

function add_metadata!(analysis_file, raw_data)

    copy_object(raw_data, "system", analysis_file, "system")
    copy_object(raw_data, "integration_info", analysis_file, "integration_info")

    return analysis_file
end


function analyze_single(custom_analysis_function, analysis_save_path, raw_data_file_path ;
                        support_raw_data_file_path=nothing,  mode::Symbol=:new)
    raw_data = load_file(raw_data_file_path)
    try
        support_data = isnothing(support_raw_data_file_path) ? nothing : load_file(support_raw_data_file_path)
        try
            analysis_file = initialize_file(analysis_save_path; mode)
            if mode==:new
                add_metadata!(analysis_file, raw_data)
            end

            try
                custom_analysis_function(analysis_file, raw_data; support_raw_data_file=support_data)
            finally
                close(analysis_file)
            end
        finally
            isnothing(support_data) || close(support_data)
        end
    finally
        close(raw_data)
    end
end

export save_dict2h5!
function save_dict2h5!(file, dict, dictsavename)

    create_group(file, dictsavename)

    for (key, val) in dict
        file[dictsavename][string(key)] = val
    end
    return file
end


function extract_frame_data(datakey, frame_data; type = type)

    if isnothing(type)
        return frame_data[datakey]

    else
        return frame_data[datakey][ frame_data["type"].==type ]
    end

end


function collect_over_frames(datakey, file; type = nothing, start=1, stop=nothing, step = 1)

    t = file["integration_info"]["save_tax"]

    stopr = isnothing(stop) ? length(t) : stop

    frame_numbers = collect(range(start = start, step = step, stop = stopr))
    Nt = length(frame_numbers)

    Np = length(extract_frame_data("id", file["frames"]["1"], type=type))

    #remember: Julia is column major, so for speed do this
    data = zeros(Np,Nt)

    for (i, fi) in enumerate(frame_numbers)

        data[:,i] =  extract_frame_data(datakey, file["frames"][string(fi)], type=type)
    end

    return data
end

function findfile(directory, filepattern)

    paths = String[]

    for (root, dirs, files) in walkdir(directory)

        for file in files

            if occursin(filepattern, file) && endswith(file, ".h5")

                push!(paths, joinpath(root, file))
            end
        end
    end

    return paths
end


function auto_analysis_dir(base_folder, raw_data_file_name_pattern; support_raw_data_file_name_pattern = nothing, mimic_source_dir_name = "simdata",mimic_target_dir_name = "analysis")

    raw_data_file_paths = findfile(base_folder, raw_data_file_name_pattern)

    support_raw_data_file_paths = isnothing(support_raw_data_file_name_pattern) ? nothing : findfile(base_folder, support_raw_data_file_name_pattern)

    seed_dir_names = [ splitpath(dirname(file_path))[end] for file_path in raw_data_file_paths]

    analysis_save_folders = replace.( dirname.(dirname.(raw_data_file_paths)), mimic_source_dir_name => mimic_target_dir_name) 

    analysis_save_paths = [joinpath(analysis_save_folders[i],seed_dir_names[i]*".h5") for i=eachindex(seed_dir_names)]


    return analysis_save_paths, raw_data_file_paths, support_raw_data_file_paths

end


function auto_ensemble_dir(base_folder, analysis_file_name_pattern; mimic_source_dir_name = "analysis", mimic_target_dir_name = "ensembles")

    #Find all analysis files
    analysis_file_paths = findfile(base_folder, analysis_file_name_pattern)

    display(analysis_file_paths)

    #Construct ensemble save folder structures
    ensemble_save_folders = unique(replace.( dirname.(analysis_file_paths), mimic_source_dir_name => mimic_target_dir_name))

    ensemble_save_paths = joinpath.(ensemble_save_folders,"ensemble.h5")

    seed_file_paths_per_ensemble_folder = []
    
    for i in eachindex(ensemble_save_folders)

        #Corresponding analysis folder
        analysis_folder  = replace.( ensemble_save_folders[i], mimic_target_dir_name => mimic_source_dir_name) 

        #Find all seeds in this folder
        seed_paths_in_ensemble = findfile(analysis_folder, analysis_file_name_pattern)

        #Add these file paths to the corresponding ensemble
        push!(seed_file_paths_per_ensemble_folder,seed_paths_in_ensemble)
    end


    return ensemble_save_paths, seed_file_paths_per_ensemble_folder
end


#module end
end