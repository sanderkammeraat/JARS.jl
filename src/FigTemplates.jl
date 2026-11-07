
const inch = 96.0
const pt   = 4 / 3
const cm   = inch / 2.54

export sans_serif_theme
function sans_serif_theme(; fontsize = 8pt)
    set_default_font_family!(:fira_math)
    ff = default_font_family()
    return Theme(
    fontsize = fontsize,
    figure_padding = (3, 1.3fontsize, 3, 0.7fontsize) ,
    fonts = (;
    regular    = ff.regular,
    bold       = ff.bold,
    italic     = ff.italic,
    bolditalic = ff.bolditalic,
    ),
    Axis = (
        xlabelsize = fontsize,  
        xticklabelsize = fontsize,
        yticklabelsize = fontsize, 
        ylabelsize = fontsize,
        xtickalign = 1,        
        ytickalign = 1,
        xticksmirrored = true,
        yticksmirrored = true,
        xminorticksvisible = true,
        yminorticksvisible = true,
        xminortickalign = 1,
        yminortickalign = 1,
        xminorticks = IntervalsBetween(4),
        yminorticks = IntervalsBetween(4),
        xgridvisible = false, 
        ygridvisible = false,
    ),
    Legend = (
        labelsize = fontsize,
        framevisible = false,
        tellheight=false,
        tellwidth=true,
        halign=:left
    ))
end

export serif_theme
function serif_theme(; fontsize = 8pt)
    set_default_font_family!(:new_cm)
    ff = default_font_family()
    return Theme(
    fontsize = fontsize,
    figure_padding = (3, 1.3fontsize, 3, 0.7fontsize) ,
    fonts = (;
    regular    = ff.regular,
    bold       = ff.bold,
    italic     = ff.italic,
    bolditalic = ff.bolditalic,
    ),
    Axis = (
        xlabelsize = fontsize,  
        xticklabelsize = fontsize,
        yticklabelsize = fontsize, 
        ylabelsize = fontsize,
        xtickalign = 1,        
        ytickalign = 1,
        xticksmirrored = true,
        yticksmirrored = true,
        xminorticksvisible = true,
        yminorticksvisible = true,
        xminortickalign = 1,
        yminortickalign = 1,
        xminorticks = IntervalsBetween(4),
        yminorticks = IntervalsBetween(4),
        xgridvisible = false, 
        ygridvisible = false,
    ),
    Legend = (
        labelsize = fontsize,
        framevisible = false,
        tellheight=false,
        tellwidth=true,
        halign=:left
    ))
end


Figure1col() = Figure(size = (8.5cm, 8.5cm))
Figure2col() = Figure(size = (17cm, 8.5cm))

function adjust_height!(f, aspect)
    W  = f.scene.viewport[].widths[1]
    gl = f.layout
    done = Set{Int}()
    for c in gl.content
        c.content isa Axis || continue
        r, col = first(c.span.rows), first(c.span.cols)
        r in done && continue
        ncols = length(c.span.cols)              # axis spanning several columns
        rowsize!(gl, r, Aspect(col, ncols == 1 ? 1 / aspect : 1 / (aspect * ncols)))
        push!(done, r)
    end
    for _ in 1:2
        _, h = resize_to_layout!(f)
        resize!(f.scene, W, h)
    end
    return f
end

function axes_with_positions(gl)
    [(first(c.span.rows), first(c.span.cols), c.content)
     for c in gl.content if c.content isa Axis]
end
function prune_ticklabel!(ax, dir::Symbol, side::Symbol)
    lims = ax.finallimits[]
    i = dir === :y ? 2 : 1
    lo, hi = lims.origin[i], lims.origin[i] + lims.widths[i]
    ticks, scale, fmt = dir === :y ?
        (ax.yticks[], ax.yscale[], ax.ytickformat[]) :
        (ax.xticks[], ax.xscale[], ax.xtickformat[])
    vals, labels = Makie.get_ticks(ticks, scale, fmt, lo, hi)
    isempty(vals) && return ax
    k = side === :upper ? argmax(vals) : argmin(vals)
    labels = Any[labels...]
    labels[k] = ""
    dir === :y ? (ax.yticks = (vals, labels)) : (ax.xticks = (vals, labels))
    return ax
end

function prune_neighbours!(items)
    for (r, c, ax) in items
        any(it -> it[1] == r - 1 && it[2] == c, items) && prune_ticklabel!(ax, :y, :upper)
        any(it -> it[1] == r && it[2] == c + 1, items) && prune_ticklabel!(ax, :x, :upper)
    end
end

function equalize_ticklabelspace!(axs)
    ys = [ax for ax in axs if ax.yticklabelsvisible[]]   # skip hidden labels
    if !isempty(ys)
        s = maximum(tight_yticklabel_spacing!, ys)
        foreach(ax -> ax.yticklabelspace = s, ys)
    end
    xs = [ax for ax in axs if ax.xticklabelsvisible[]]
    if !isempty(xs)
        s = maximum(tight_xticklabel_spacing!, xs)
        foreach(ax -> ax.xticklabelspace = s, xs)
    end
end

function hide_repeated_labels!(items, dir::Symbol)
    group = dir === :x ? 2 : 1          # x: per column, y: per row
    order = dir === :x ? 1 : 2
    for g in unique(it[group] for it in items)
        grp  = sort([it for it in items if it[group] == g]; by = it -> it[order])
        keep = dir === :x ? grp[end][3] : grp[1][3]   # bottom / leftmost
        for (_, _, ax) in grp
            ax === keep && continue
            if dir === :x
                ax.xlabel[] == keep.xlabel[] && (ax.xlabelvisible = false)
            else
                ax.ylabel[] == keep.ylabel[] && (ax.ylabelvisible = false)
            end
        end
    end
end

function compress_whitespace!(f; sharex = false, sharey = false, sharexlabel = sharex, shareylabel = sharey,
    gap = 4, col_gap = gap, row_gap = gap, aspect = 4/3)
    gl    = f.layout
    items = axes_with_positions(gl)

    if sharex   # per column: link x, keep tick labels only on the bottom axis
        for col in unique(c for (_, c, _) in items)
            axs = [ax for (_, _, ax) in sort([it for it in items if it[2] == col]; by = first)]
            length(axs) > 1 || continue
            linkxaxes!(axs...)
            foreach(ax -> hidexdecorations!(ax; ticks = false, minorticks = false), axs[1:end-1])
        end
    end

    if sharey   # per row: link y, keep tick labels only on the leftmost axis
        for row in unique(r for (r, _, _) in items)
            axs = [ax for (_, _, ax) in sort([it for it in items if it[1] == row]; by = it -> it[2])]
            length(axs) > 1 || continue
            linkyaxes!(axs...)
            foreach(ax -> hideydecorations!(ax; ticks = false, minorticks = false), axs[2:end])
        end
    end

    sharexlabel && hide_repeated_labels!(items, :x)
    shareylabel && hide_repeated_labels!(items, :y)

    prune_neighbours!(items)
    equalize_ticklabelspace!(last.(items))
    colgap!(gl, col_gap)
    rowgap!(gl, row_gap)
    adjust_height!(f, aspect)
    return f
end

export Figure1col, Figure2col, compress_whitespace!