
using JARS
using GLMakie
using Observables

@views function make_movie(raw_data_file,save_path)
    save_tax = raw_data_file["integration_info"]["save_tax"]


    L = raw_data_file["system"]["sizes"][1]
    frame_numbers = 1:100:length(save_tax)

    frames = raw_data_file["frames"]

    t = Observable(0.)

    x = Observable(frames["1"]["x"]) 
    y = Observable(frames["1"]["y"]) 

    vx = Observable(frames["1"]["vx"])
    vy = Observable(frames["1"]["vy"]) 

    px = Observable(frames["1"]["px"])
    py = Observable(frames["1"]["py"]) 
    type = frames["1"]["type"]

    R = Observable(frames["1"]["R"]) 
    
    #Setup figure
    f = Figure(size=(1000,1000))#Figure(size=(2000,2000));
    ax = Axis(f[1,1], aspect=DataAspect(),title = @lift("t = $(round($t, digits = 1))"), xlabel="x", ylabel="y");


    #disks
    c = type
    s = @lift( 2. *$R)

    #directors
    cp = @lift( angle.($px+1im*$py) )


    #arrows!(ax, x,y, px,py , color=cp,  colormap=:hsv,colorrange=(-pi,pi))

    #velocity vectors
    cv = @lift( angle.($vx+1im*$vy) )

    vp_x = @lift( cos.($cp-$cv))

    vp_y = @lift( sin.($cp-$cv) )

    #arrows!(ax, x,y, vx,vy , color=cv,  colormap=:hsv,colorrange=(-pi,pi))

    scatter!(ax,x,y, color=cv, markersize =s,marker = Circle, markerspace=:data, strokecolor=:black, strokewidth=1, colormap=:hsv,colorrange=(-pi,pi))


    display(f)
    save_path = mkpath(save_path)
    record(f,save_path, frame_numbers; visible=false) do i 

        stri = string(i)
        t[] = frames[stri]["t"]
        #tplot[]=push!(tplot[], frames[stri]["t"] )

        

        x[] =   frames[stri]["x"]
        y[] = frames[stri]["y"]

        vx[] = frames[stri]["vx"]
        vy[] = frames[stri]["vy"]

        px[] = frames[stri]["px"]
        py[] = frames[stri]["py"]

        
    end
    close(raw_data_file)
end

base_folder = "/Users/kammeraat/mounting/alicedata1_kammeraatsc1/jamming/exploration/pf_sweep_d2/simdata"

mp, rp, sp = JIO.auto_movie_dir(base_folder, "sa_raw_data.h5",support_raw_data_file_name_pattern= "ra_raw_data.h5")

for i in eachindex(mp)
    raw_data_file = JIO.load_file(rp[i])
    make_movie(raw_data_file, mp[i])
end
