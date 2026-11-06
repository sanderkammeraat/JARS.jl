
#Observables
module JOB

using HDF5
using JLD2
using FFTW
using LinearAlgebra
using DataFrames
using Statistics

function MSD(t,x,y; z=nothing, tavg=true, pavg = true)

    msd = zeros(length(t))

    if isnothing(z)
        @Threads.threads for i in eachindex(msd)
            msd[i] = @views mean( (x[:,i:end] .- x[:,1:end-i+1]) .^2 .+ (y[:,i:end] .- y[:,1:end-i+1]) .^2 )

        end

    else
        @Threads.threads for i in eachindex(msd)
            msd[i] = @views mean( (x[:,i:end] .- x[:,1:end-i+1]) .^2 + (y[:,i:end] .- y[:,1:end-i+1]) .^2 .+ (z[:,i:end] .- z[:,1:end-i+1]) .^2 )

        end
    end



    return Dict("msd" => msd, "lagtime"=> t)

end




end