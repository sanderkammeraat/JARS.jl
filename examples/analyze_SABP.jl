
using JARS


sa_file = JIO.load_file(joinpath(homedir(), "testdata_JARS","sa_raw_data.h5"))

system_sizes = sa_file["system"]["sizes"]
step = 10

T1 = JIO.extract_trajectories_polar(sa_file, type = 1, step=1)

begin
x0 = sa_file["frames"]["1"]["x"]
y0 = sa_file["frames"]["1"]["y"]

karray = sa_file["system"]["forces"]["pair"]["repulsive_soft_disk"]["karray"]


end
begin
msd = JOB.MSD(t,x, y, z)

vop = JOB.vicsek_order_parameter(t, px, py, pz)
vvop = JOB.vicsek_order_parameter(t, vx, vy, vz)

rBins = JOB.linear_bins(3, 100)
Cvv_r = JOB.spatial_correlation(rBins, x, y, z, vx, vy, vz; RMS_normalization=true, system_sizes=system_sizes)
Cvv_r_np = JOB.spatial_correlation(rBins, x, y, z, vx, vy, vz; RMS_normalization=true, system_sizes=nothing)

Cvv_r_nm = JOB.spatial_correlation(rBins, x, y, z, vx, vy, vz; RMS_normalization=true, system_sizes=system_sizes, remove_mean=true)
 #; system_sizes = system_sizes)

Cnn_r = JOB.spatial_correlation(rBins, x, y, z, px, py, pz; system_sizes=system_sizes)


Cvv_t = JOB.auto_correlation(t, vx, vy, vz)
Cnn_t = JOB.auto_correlation(t, px, py, pz)
end
D = JOB.construct_D(x0, y0, karray, R,types ;periodic_system_sizes=system_sizes)

eigenfact = JOB.diagonalize_D(D)
eigvecs = eigenfact["eigvecs"]
projs = JOB.project_on_eigvecs(eigvecs, x, y)

eigvals = eigenfact["eigvals"]
avg_projs_2 = mean( projs.^2, dims = 2)[1:end]


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


