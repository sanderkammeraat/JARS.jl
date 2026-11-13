
using JARS

base_folder = "/Users/kammeraat/jamming/"

ap, rp, sp = JIO.auto_analysis_dir(base_folder, "sa_raw_data.h5",support_raw_data_file_name_pattern= "ra_raw_data.h5")


ind = 1


function cf!(analysis_file, raw_data_file; support_raw_data_file = nothing)
    
    save_tax = analysis_file["integration_info"]["save_tax"]

    #Steady state trajectories
    Ts = JIO.extract_trajectories_polar(raw_data_file, type =1 ,start = div(3*length(save_tax),4))
    rBins = JOB.linear_bins(3, 100)

    #One line computations
    observables = [
        "MSD"   =>  () -> JOB.MSD(Ts.t, JIO.pos(Ts)...),
        "vop_n" => () ->JOB.vicsek_order_parameter(Ts.t, JIO.pol(Ts)...),
        "vop_v" => () ->JOB.vicsek_order_parameter(Ts.t, JIO.vel(Ts)...),
        "Cvv_r" => () ->JOB.spatial_correlation(rBins, JIO.pos(Ts)..., JIO.vel(Ts)...),
        "Cnn_r" => () ->JOB.spatial_correlation(rBins, JIO.pos(Ts)..., JIO.pol(Ts)...),
        "Cvv_t" => () ->JOB.auto_correlation(Ts.t, JIO.vel(Ts)...),
        "Cnn_t" => () ->JOB.auto_correlation(Ts.t, JIO.pol(Ts)...)
        ]

    for (name, f) in observables
        haskey(analysis_file, name) && continue   # skip if already computed
        JIO.save_dict2h5!(analysis_file, f(), name)
    end

    #Multi line computations

    #relax again trajectories
    save_tax_ra = support_raw_data_file["integration_info"]["save_tax"]
    Tra = JIO.extract_trajectories_polar(support_raw_data_file, start = length(save_tax_ra) -1)
    karray = analysis_file["system"]["forces"]["pair"]["repulsive_soft_disk"]["karray"]
    D_wb = JOB.construct_D(Tra.x[:,1], Tra.y[:,1], karray, Tra.R[:,1], Tra.type[:,1])

    interior_indmax = sum( Tra.type[:,1].==1 )
    D = Symmetric(D_wb[1:2*interior_indmax,1:2*interior_indmax])

    #Boundary particles are stored at the end
    eigenfact = JOB.diagonalize_D(D)
    eigvecs = eigenfact["eigvecs"]
    projs = JOB.project_on_eigvecs(eigvecs, Ts.vx, Ts.vy)

    eigvals = eigenfact["eigvals"]
    avg_projs_2 = mean( projs.^2, dims = 2)[1:end]

    create_group(analysis_file, "modes")
    analysis_file["modes"]["eigvals"] = eigvals
    analysis_file["modes"]["avg_projs_2"] = avg_projs_2



return analysis_file

end

JIO.analyze_single(cf!, ap[ind], rp[ind], support_raw_data_file_path=sp[ind])

analysis = JIO.load_file("/Users/kammeraat/jamming/analysis/pf_0.2/seed_1.h5")

msd = analysis["MSD"]
vop = analysis["vop_n"]
vvop = analysis["vop_v"]
Cvv_r = analysis["Cvv_r"]
Cnn_r = analysis["Cnn_r"]
Cvv_t = analysis["Cvv_t"]
Cnn_t = analysis["Cnn_t"]
modes = analysis["modes"]

using GLMakie

begin
    f = Figure()

    ax = Axis(f[1,1], xscale=log10, yscale=log10)

    scatterlines!(ax, msd["lagtime"], msd["msd"])
    display(f)

end

begin
    f = Figure()

    ax = Axis(f[1,1])
    scatterlines!(ax, vop["t"], vop["vop"])
    scatterlines!(ax, vvop["t"], vvop["vop"]/0.01)
    display(f)

end

begin
    f = Figure()

    ax = Axis(f[1,1])
    scatterlines!(ax, Cvv_r["r"], Cvv_r["C"])
    # scatterlines!(ax, Cvv_r_np["r"], Cvv_r_np["C"])
    # scatterlines!(ax, Cvv_r_nm["r"], Cvv_r_nm["C"])
    scatterlines!(ax, Cnn_r["r"], Cnn_r["C"])
    display(f)

end

begin
    f = Figure()

    ax = Axis(f[1,1])
    scatterlines!(ax, Cvv_t["lagtime"], Cvv_t["C"])
    scatterlines!(ax, Cnn_t["lagtime"], Cnn_t["C"])

    display(f)

end

begin
    f = Figure()

    ax = Axis(f[1,1])
    scatterlines!(ax, modes["eigvals"])
    display(f)

end

begin
    f = Figure()

    ax = Axis(f[1,1], yscale=log10)
    scatterlines!(ax, modes["eigvals"], modes["avg_projs_2"])
    display(f)

end

