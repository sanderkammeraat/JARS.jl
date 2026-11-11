
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

function equalize_ticklabelspace!(items)
    for col in unique(it[2] for it in items)
        ys = [it[3] for it in items if it[2] == col && it[3].yticklabelsvisible[]]
        isempty(ys) && continue
        s = maximum(tight_yticklabel_spacing!, ys)
        foreach(ax -> ax.yticklabelspace = s, ys)
    end
    for row in unique(it[1] for it in items)
        xs = [it[3] for it in items if it[1] == row && it[3].xticklabelsvisible[]]
        isempty(xs) && continue
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
    for (_, _, ax) in axes_with_positions(f.layout)
        reset_limits!(ax)
    end
    share!(f; x = sharex, y = sharey, xlabel = sharexlabel, ylabel = shareylabel)
    items = axes_with_positions(f.layout)
    prune_neighbours!(items)
    equalize_ticklabelspace!(items)
    colgap!(f.layout, colgap)
    rowgap!(f.layout, rowgap)
    adjust_height!(f; aspect)
    return f
end

function label_panels!(f; inside = false, order = :row,
                       fmt   = i -> "($('a' + i - 1))",
                       pos   = (0.04, 0.96),
                       at    = Dict{Int,NTuple{2,Float64}}(),
                       font  = :regular,
                       raise = 0.6 * Makie.theme(:fontsize)[])   # lift for outside labels
    items = axes_with_positions(f.layout)
    sort!(items; by = it -> order === :row ? (it[1], it[2]) : (it[2], it[1]))
    for (i, (r, c, ax)) in enumerate(items)
        if inside
            p = get(at, i, pos)
            text!(ax, p...; text = fmt(i), space = :relative, font = font,
                  align = (p[1] < 0.5 ? :left : :right, p[2] < 0.5 ? :bottom : :top))
        else
            Label(f[r, c, TopLeft()], fmt(i); font = font,
                  halign = :right, valign = :bottom,
                  padding = (0, 4, raise, 0))    # (left, right, bottom, top)
        end
    end
    return f
end
export Figure1col, Figure2col, compress_whitespace!, share!, adjust_height!, label_panels!