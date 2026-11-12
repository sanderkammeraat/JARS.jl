

#Custom function as if having loaded a single simulation
function run_custom_analysis_function_template!(analysis_file, raw_data_file; support_raw_data_file = nothing)



    #px = Logistics.collect_over_frames("px", raw_data_file, type=1)

    #FT_px = temporal_Fourier_transform(dt, px)

    #save_dict2h5!(analysis_file,FT_px, "FT_px")

    #or e.g.

    #v2_particle_time_avg = mean( (vx.^2 + vy.^2)[:,min_t_ind:end],dims=2)[:,1]
    #analysis_file["v2_particle_time_avg"] = v2_particle_time_avg

    #Then return modifed analysis file
    return analysis_file

end

