module JARS

using HDF5
using JLD2
using FFTW
using LinearAlgebra
using Reexport
using DataFrames
using Statistics

#This order is dictated by https://github.com/dawbarton/TeXLayout.jl
#Shout out to David Barton for this nice package!
using TeXLayout
using CairoMakie, LaTeXStrings
include("FigTemplates.jl")

__init__() = set_theme!(sans_serif_theme())

include("JIO.jl")

include("JOB.jl")

include("CustomAnalysisFunctions.jl")

@reexport using .JOB

@reexport using .JIO


end
