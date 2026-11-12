
using JARS

base_folder = "/Users/kammeraat/mounting/alicedata1_kammeraatsc1/jamming/exploration/pf_sweep_d2/"

ap, rp, sp = JIO.auto_analysis_dir(base_folder, "sa_raw_data.h5",support_raw_data_file_name_pattern= "ra_raw_data.h5")


ind = 1


function cf!(analysis_file, raw_data_file; support_raw_data_file = nothing)
    
    save_tax = analysis_file["integration_info"]["save_tax"]

    Ts = JIO.extract_trajectories_polar(raw_data_file, type =1 ,start = div(3*length(save_tax),4))
    
    save_dict2h5!(analysis_file,JOB.MSD(Ts.t, Ts.x, Ts.y, Ts.z) ,"MSD")

    save_dict2h5!(analysis_file,JOB.vicsek_order_parameter(Ts.t, Ts.px, Ts.py, Ts.pz),"vop_n")
    save_dict2h5!(analysis_file,JOB.vicsek_order_parameter(Ts.t, Ts.vx, Ts.vy, Ts.vz),"vop_v")

    rBins = JOB.linear_bins(3, 100)
    save_dict2h5!(analysis_file,JOB.spatial_correlation(rBins, Ts.x, Ts.y, Ts.z, Ts.vx, Ts.vy, Ts.vz), "Cvv_r")

    save_dict2h5!(analysis_file,JOB.spatial_correlation(rBins, Ts.x, Ts.y, Ts.z, Ts.px, Ts.py, Ts.pz),"Cnn_r")

    save_dict2h5!(analysis_file,JOB.auto_correlation(Ts.t, Ts.vx, Ts.vy, Ts.vz), "Cvv_t")
    save_dict2h5!(analysis_file,JOB.auto_correlation(Ts.t, Ts.px, Ts.py, Ts.pz), "Cnn_t")

return analysis_file

end




JIO.analyze_single(cf!, ap[ind], rp[ind], support_raw_data_file_path=sp[ind])

