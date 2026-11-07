
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

function adjust_height!(f; aspect =4/3)
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
# pick the subset of (row, col, ax) items to act on
function select_items(items, cells)
    cells === :all && return items
    cells isa Tuple && return [it for it in items if it[1] in cells[1] && it[2] in cells[2]]
    return [it for it in items if any(ax -> ax === it[3], cells)]   # vector of Axis
end

function share_dir!(items, dir::Symbol)
    group = dir === :x ? 2 : 1          # x: per column, y: per row
    order = dir === :x ? 1 : 2
    for g in unique(it[group] for it in items)
        axs = [it[3] for it in sort([it for it in items if it[group] == g]; by = it -> it[order])]
        length(axs) > 1 || continue
        if dir === :x
            linkxaxes!(axs...)
            foreach(ax -> hidexdecorations!(ax; ticks = false, minorticks = false), axs[1:end-1])
        else
            linkyaxes!(axs...)
            foreach(ax -> hideydecorations!(ax; ticks = false, minorticks = false), axs[2:end])
        end
    end
end

function share!(f; x = false, y = false, xlabel = x, ylabel = y, cells = :all)
    items = select_items(axes_with_positions(f.layout), cells)
    x      && share_dir!(items, :x)
    y      && share_dir!(items, :y)
    xlabel && hide_repeated_labels!(items, :x)
    ylabel && hide_repeated_labels!(items, :y)
    return f
end


function compress_whitespace!(f; sharex = false, sharey = false,
                              sharexlabel = sharex, shareylabel = sharey,
                              gap = 4, colgap = gap, rowgap = gap, aspect = 4/3)
    share!(f; x = sharex, y = sharey, xlabel = sharexlabel, ylabel = shareylabel)
    items = axes_with_positions(f.layout)
    prune_neighbours!(items)
    equalize_ticklabelspace!(last.(items))
    colgap!(f.layout, colgap)
    rowgap!(f.layout, rowgap)
    adjust_height!(f; aspect)
    return f
end
export Figure1col, Figure2col, compress_whitespace!, share!, adjust_height!