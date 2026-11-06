
using JARS


sa_file = JIO.load_file(joinpath(homedir(), "testdata_JARS","sa_raw_data.h5"))

t = sa_file["integration_info"]["save_tax"]

x = JIO.collect_over_frames("x",sa_file,type=1)

y = JIO.collect_over_frames("y",sa_file,type=1)

z = JIO.collect_over_frames("z",sa_file,type=1)

msd = JOB.MSD(t,x, y, z=z)

@profview JOB.MSD(t,x, y, z=z)

using GLMakie

begin
    f = Figure()

    ax = Axis(f[1,1], xscale=log10, yscale=log10)

    scatterlines!(ax, msd["lagtime"], msd["msd"])
    display(f)

end

