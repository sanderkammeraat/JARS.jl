

#Observables
module JOB

using HDF5
using JLD2
using FFTW
using LinearAlgebra
using DataFrames
using Statistics
using ProgressMeter
using StaticArrays
#Always return Dict that contain both axes for plotting, so e.g. include a t axis

function MSD(t,x,y,z; tavg=true, pavg = true)

    msd = zeros(length(t))

    @Threads.threads for i in eachindex(msd)
        msd[i] = @views mean( (x[:,i:end] .- x[:,1:end-i+1]) .^2 + (y[:,i:end] .- y[:,1:end-i+1]) .^2 .+ (z[:,i:end] .- z[:,1:end-i+1]) .^2 )

    end

    return Dict("msd" => msd, "lagtime"=> t .- t[1])

end

function vicsek_order_parameter(t, px, py, pz)

    mean_xt = mean(px, dims = 1)[1:end]
    mean_yt = mean(py, dims = 1)[1:end]
    mean_zt = mean(pz, dims = 1)[1:end]

    vop = @. sqrt( mean_xt^2 + mean_yt^2 + mean_zt^2)

    return Dict("vop" => vop, "t" => t)

end

struct Bins
    centers::Vector{Float64}
    edges::Vector{Float64}
    edges2::Vector{Float64}
    sizes::Vector{Float64}
    Nbins::Int64
end


function linear_bins(bin_size, bins_extent)

    edges = prepend!(collect(range(start=0., step = bin_size, stop = bins_extent)),[0.])

    edges2 = edges.^2

    centers = (edges[2:end] .+ edges[1:end-1]) ./2

    bin_sizes =  edges[2:end] .- edges[1:end-1] 

    return Bins(centers, edges, edges2, bin_sizes, length(centers))

end


function spatial_correlation(bins::Bins, x, y, z,  vx, vy, vz;
    RMS_normalization = true, system_sizes = nothing, remove_mean = false)
    
    ( size(x,2) == size(vx, 2) ==size(y,2) == size(vy, 2) ==size(z,2) == size(vz, 2) ) || error("All arrays should have the same time axis length")

    Nbins = bins.Nbins
    Nt = size(vx,2)

    C = ones(Nt, Nbins)*NaN

    counts = zeros(Nt, Nbins)

    vxm = remove_mean ? vx .- mean(vx, dims=1) : vx
    vym = remove_mean ? vy .- mean(vy, dims=1) : vy
    vzm = remove_mean ? vz .- mean(vz, dims=1) : vz

    @showprogress dt = 1 desc="spatial correlation" showspeed=true Threads.@threads for i in 1:Nt

        vrms_2_i = RMS_normalization ? mean( @views vxm[:, i].^2 .+ vym[:, i].^2 .+ vzm[:, i].^2) : 1.

        for v1 in 1:size(vx,1)

            for v2 in v1:size(vx,1)

                dx = isnothing(system_sizes) ? x[v1, i]- x[v2,i] : minimal_image_difference_component(x[v1, i]- x[v2,i],system_sizes[1], true)
                dy = isnothing(system_sizes) ? y[v1, i]- y[v2,i] : minimal_image_difference_component(y[v1, i]- y[v2,i],system_sizes[2], true)
                dz = isnothing(system_sizes) ? z[v1, i]- z[v2,i] : minimal_image_difference_component(z[v1, i]- z[v2,i],system_sizes[3], true)

                delta_r2 = dx^2 +   dy^2 +  dz^2

                for bin in eachindex(bins.centers)
                    #inbounds, compiler may not know that rbin_centers is shorter than edges

                    @inbounds if (delta_r2<= bins.edges2[bin+1] && delta_r2> bins.edges2[bin]) || (v1==v2 && bin==1)

                        if isnan(C[i, bin])
                            C[i, bin]=0
                            counts[i, bin]=0
                        end

                        C[i, bin] +=( vxm[v1, i]* vxm[v2, i] + vym[v1, i] * vym[v2, i] + vzm[v1, i] * vzm[v2, i])/vrms_2_i
                        counts[i,bin] += 1
                    end

                end

            end
        end
    end
    C.=C./counts
    Cavg = mean(C, dims=1)[1,:]
    return Dict("r"=>bins.centers, "C"=> Cavg)
end



function auto_correlation(t,  vx, vy, vz;
    RMS_normalization = true, remove_mean = false)

    (size(t,1) == size(vx, 2 ) == size(vy, 2) == size(vz, 2)) || error("Arrays should be equally long along time axis.")

    Nt = length(t)

    delta_t = zeros(Nt)
    Cavg = zeros(Nt)

    C = ones(Nt, Nt)*NaN


    vxm = remove_mean ? vx .- mean(vx, dims=1) : vx
    vym = remove_mean ? vy .- mean(vy, dims=1) : vy
    vzm = remove_mean ? vz .- mean(vz, dims=1) : vz

    @showprogress dt = 1 desc="autocorrelation" showspeed=true Threads.@threads for i in 1:Nt

        vrms_i = RMS_normalization ? sqrt(mean( @views vxm[:, i].^2 .+ vym[:, i].^2 .+ vzm[:, i].^2)) : 1.

        for j in i:Nt

            vrms_j = RMS_normalization ? sqrt(mean( @views vxm[:, j].^2 .+ vym[:, j].^2 .+ vzm[:, j].^2)) : 1.

            C[i,j-i+1] = mean( @views vxm[:,j].* vxm[:,i] .+ vym[:,j].* vym[:,i] .+ vzm[:,j].* vzm[:,i]) /vrms_i/vrms_j
        end
    end
    for j in 1:Nt
        Cavg[j] = mean( filter!( e->!isnan(e) ,C[:,j] ) )
    end
    return Dict("lagtime"=>t .-t[1], "C"=> Cavg)
end


#Helper function from JAMS
@inbounds function minimal_image_difference(xi, xj, system_sizes, system_Periodic)
    
    dx_x = minimal_image_difference_component(xj[1]-xi[1],system_sizes[1], system_Periodic)
    dx_y = minimal_image_difference_component(xj[2]-xi[2],system_sizes[2], system_Periodic)
    dx_z = minimal_image_difference_component(xj[3]-xi[3],system_sizes[3], system_Periodic)
    return Float64[dx_x, dx_y, dx_z]
end
function minimal_image_difference_component(linear_difference,linear_size, system_Periodic)

        if system_Periodic
            if linear_difference>linear_size/2
                linear_difference-=linear_size
            end
            if linear_difference<=-linear_size/2
                linear_difference+=linear_size
            end
        end 

    return linear_difference
end



## Dynamical matrix analysis
# Helper functions
function construct_n_ij_projector!(n_ij_projector, i,j,x,y, periodic_system_sizes)


    r_ij_0_vec = @MVector [x[j]-x[i], y[j] - y[i]]

    r_i_0_vec = @MVector [x[i],y[i]]
    r_j_0_vec = @MVector [x[j],y[j]]

    if !isnothing(periodic_system_sizes)
        r_ij_0_vec = minimal_image_difference!(r_ij_0_vec, r_i_0_vec, r_j_0_vec, periodic_system_sizes, true)
    end

    r_ij_0_norm = norm(r_ij_0_vec)

    n_ij =r_ij_0_vec./r_ij_0_norm

    n_ij_projector[1,1] = n_ij[1]*n_ij[1]
    n_ij_projector[1,2] = n_ij[1]*n_ij[2]
    n_ij_projector[2,1] = n_ij[1]*n_ij[2]
    n_ij_projector[2,2] = n_ij[2]*n_ij[2]

    return n_ij_projector, r_ij_0_norm
end

function u_ij_1(i,j,r_ij_0_norm, k, R,type)
    #If not the same
    if i==j
        return 0.

    #If different
    elseif i!=j
        #If in 
        a = R[i]+R[j]
        if r_ij_0_norm<=a
            return k[type[i],type[j]] * (r_ij_0_norm - a)

        else
            return 0.
        end
    end
end

function u_ij_2(i,j,r_ij_0_norm, k, R,type)
    #If the same
    if i==j
        return 0.

    #If different
    elseif i!=j
        #If in 
        a = R[i]+R[j]
        if r_ij_0_norm<=a
            return k[type[i],type[j]]
        else
            return 0.
        end
    end
end

@views function construct_M_ij!(M_ij,n_ij_projector, i,j,x,y, k, R,type, periodic_system_sizes)

    M_ij .*=  0

    if i!=j
        n_ij_projector, r_ij_0_norm = construct_n_ij_projector!(n_ij_projector,i,j,x,y,periodic_system_sizes)

        M_ij.+= -u_ij_1(i,j,r_ij_0_norm, k, R, type) ./ r_ij_0_norm .* (I - n_ij_projector)

        M_ij.+= u_ij_2(i,j,r_ij_0_norm, k, R, type) .* n_ij_projector

    end

    return M_ij

end
function construct_D(x0, y0, k, R,type ;periodic_system_sizes=nothing)
    D=zeros(2*length(x0), 2*length(x0))
    Id = [1 0 ; 0 1]
    nij = zeros(2,2)
    dX = @MVector [0., 0., 0.]
    for i in eachindex(x0)
        for j in eachindex(x0)
            if i!==j

                dX[1] = x0[j] - x0[i]
                dX[2] = y0[j] - y0[i]

                if isnothing(periodic_system_sizes)
                else
                    dX = minimal_image_difference([x0[i],y0[i],0], [x0[j],y0[j],0],periodic_system_sizes,true )
                end
                dx = dX[1]
                dy = dX[2]

                dr2 = dx^2 + dy^2
                dr = sqrt(dr2)
                kij = k[type[i],type[j]]

                Rij = R[i]+R[j]
                if dr<Rij
                    nij[1,1] =  dx*dx/dr2
                    nij[1,2] =  dx*dy/dr2
                    nij[2,1] =  dx*dy/dr2
                    nij[2,2] =  dy*dy/dr2
                    D[2i-1:2i,2j-1:2j] = -kij * nij - kij * (1 - Rij/dr) * (Id .- nij)

                    D[2i-1:2i, 2i-1:2i] -= D[2i-1:2i,2j-1:2j]

                end

            end

        end

    end
    #By applying
    return Symmetric(D)
end




function diagonalize_D(D)

    eigenfact = eigen(D)
    return Dict("eigvals"=>eigenfact.values, "eigvecs"=>eigenfact.vectors)

end





function project_on_eigvecs(eigvecs, xinterior, yinterior)

    Neigvecs = size(eigvecs)[2]
    Nt = size(xinterior)[2]

    projs = zeros(Neigvecs, Nt)

    @showprogress dt = 1 desc="Projection on eigvecs" showspeed=true   for i in 1:Nt

        for j in 1:Neigvecs
             projs[j,i] =  project_on_eigvec(eigvecs[:,j], xinterior[:,i], yinterior[:,i])

        end
    end

    return projs
end

function project_on_eigvec(eigvec, xi, yi)
    proj=0
    for k in eachindex(xi)
        proj+= xi[k] * eigvec[(2*k -1)] + yi[k] * eigvec[(2*k)]
    end
    return proj
end


function temporal_Fourier_transform(dt, x; avg_along_dim1=false)

    #Calculate the Fourier transform along the time axis for a real signal

    Xf =rfft(x, 2 )

    #Times 2 π to get angular frequency
    w = convert(Array, rfftfreq( size(x)[2], 1/dt).*2*pi)


    Xf2 = abs.(Xf).^2

    if avg_along_dim1

        @views pavg_Xf2 = mean(Xf2, dims=1)[1,:]

        maxval, maxind = findmax(pavg_Xf2)

        w_max = w[maxind]

        FT = Dict("X2"=>pavg_Xf2, "w"=>w, "max_X2"=>maxval, "max_X2_ind" =>maxind, "w_max"=>w_max )

    else
        maxval, maxind = findmax(Xf2, dims=2)
        w_max = [w[ci[2]] for ci in maxind[:,1] ]
        FT = Dict("X2"=> Xf2,  "w" =>w , "max_X2"=>maxval, "max_X2_ind" =>maxind, "w_max"=>w_max )
    end
    return FT

end



#End of module
end