# Temporary SquareModels 0.10.0 patches. Remove this file when they are fixed upstream.
# Model.jl includes this file before the modules, and GREU.__init__ calls patch_square_models!().
# Julia forbids changes to SquareModels during precompilation, so those changes run when GREU loads.
# 1. copy() returns ModelDictionary{Any}.
# 2. Equations cannot be tagged. Tag(:override) lets one equation replace another for the same variable.
# 3. @block below reads `variable :: Tag, equation` and tags that equation.

import SquareModels
import SquareModels: Tag, isexpr

# ============================================================================
# Changes to SquareModels, run when GREU loads
# ============================================================================
const square_models_patched = Ref(false)

function patch_square_models!()
  square_models_patched[] && return nothing
  square_models_patched[] = true

  # 1. Julia sometimes mis-dispatches the pattern `Dictionary{String,Union{Nothing,T}} where T`
  # (no match, or T = Any). Take T from the dictionary's element type instead.
  @eval SquareModels begin
    foreach(Base.delete_method, collect(methods(_new_model_dictionary)))

    function _new_model_dictionary(model, dictionary::Dictionary{String}, layout, full,
            variables::Vector{V}, positions=nothing) where {V<:AbstractVariableRef}
        T = _numeric_storage_type(eltype(dictionary))
        return ModelDictionary{T,typeof(model),typeof(layout),V}(
            model, dictionary, layout, layout.revision,
            full, variables, positions,
        )
    end
  end

  # 2. tag!(block, tags...) tags every equation in a block. tags(equation) and has_tag(equation, tag)
  # read them. Tags follow the equation expression, so they survive copy() and sums of blocks.
  # When blocks are summed, an equation tagged Tag(:override) replaces the other equations for the
  # same endogenous variable. Other duplicate endogenous variables still raise an error.
  @eval SquareModels begin
    const _equation_tags = IdDict{Any,Set{Tag}}()
    const _override = Tag(:override)

    function tag!(block::Block, new_tags::Tag...)
      for equation in block.equations
        union!(get!(Set{Tag}, _equation_tags, equation.func), new_tags)
      end
      return block
    end

    tags(equation::Equation) = get(_equation_tags, equation.func, Set{Tag}())
    has_tag(equation::Equation, tag::Tag) = tag ∈ tags(equation)

    # Drop the equations that an override equation replaces.
    function _apply_overrides(blocks)
      overridden = Set{VariableRef}(
        v for b in blocks for (v, eq) in zip(b.endogenous, b.equations) if has_tag(eq, _override)
      )
      isempty(overridden) && return blocks
      return map(blocks) do b
        mask = [!(v in overridden) || has_tag(eq, _override) for (v, eq) in zip(b.endogenous, b.equations)]
        all(mask) && return b
        equations = b.equations[mask]
        variables = Set{VariableRef}()
        foreach(eq -> collect_variables!(variables, eq.func), equations)
        Block(b.model, b.endogenous[mask], b.residuals[mask], variables, equations, b.test_constraints)
      end
    end

    Base.delete_method(which(Base.sum, (AbstractVector{Block},)))

    function Base.sum(blocks::AbstractVector{Block})
      isempty(blocks) && throw(ArgumentError("Cannot sum an empty vector of blocks: a Block needs a model."))
      a = first(blocks)
      i = findfirst(b -> b.model != a.model, blocks)
      isnothing(i) || error("Cannot add $a and $(blocks[i]). Blocks must belong to the same model.")
      blocks = _apply_overrides(blocks)

      endogenous = reduce(vcat, [b.endogenous for b in blocks])
      if length(Set(endogenous)) != length(endogenous)
        counts = Dict{VariableRef,Int}()
        foreach(v -> counts[v] = get(counts, v, 0) + 1, endogenous)
        shared = unique(v for v in endogenous if counts[v] > 1)
        error("Cannot combine blocks: $(length(shared)) endogenous variable(s) appear in both blocks.\n" *
              "Overlapping endogenous variables:\n$(format_variables(shared))\n" *
              "Tag one equation with Tag(:override) to replace the other.")
      end

      return Block(
        a.model,
        endogenous,
        reduce(vcat, [b.residuals for b in blocks]),
        foldl(union!, (b.variables for b in blocks); init=Set{VariableRef}()),
        reduce(vcat, [b.equations for b in blocks]),
        reduce(vcat, [b.test_constraints for b in blocks]),
      )
    end
  end
  return nothing
end

# ============================================================================
# 3. @block with equation tags, part of GREU
# ============================================================================
"""
    @block model begin ... end

SquareModels' `@block`, where `variable :: Tag, equation` tags that equation.
A module uses it with `import ..@block`. Without tags it is SquareModels' `@block` unchanged.
"""
macro block(model, expr)
  isexpr(expr, :block) || error("@block expects `@block model begin ... end`.")
  groups = Pair{Any,Vector{Any}}[]
  function group_of(tag)
    index = findfirst(g -> g.first == tag, groups)
    isnothing(index) || return index
    push!(groups, tag => Any[])
    return length(groups)
  end
  current, pending = nothing, Any[]
  for item in expr.args
    if item isa LineNumberNode || isexpr(item, :macrocall)
      # Line numbers and @test_constraint lines belong with the next entry.
      push!(pending, item)
    elseif isexpr(item, :tuple) && length(item.args) == 2
      variable, equation = item.args
      tag = isexpr(variable, :(::)) ? variable.args[2] : nothing
      tag === nothing || (variable = variable.args[1])
      current = group_of(tag)
      append!(groups[current].second, pending, [Expr(:tuple, variable, equation)])
      empty!(pending)
    else
      # Continuation of the previous equation.
      isnothing(current) && error("@block: the first entry must be `variable, equation`.")
      append!(groups[current].second, pending, [item])
      empty!(pending)
    end
  end

  calls = map(groups) do (tag, lines)
    isempty(lines) || first(lines) isa LineNumberNode || pushfirst!(lines, __source__)
    call = Expr(:macrocall, GlobalRef(SquareModels, Symbol("@block")), __source__, model, Expr(:block, lines...))
    tag === nothing ? call : Expr(:call, GlobalRef(SquareModels, :tag!), call, tag)
  end
  length(calls) == 1 && only(groups).first === nothing && return esc(only(calls))
  return esc(Expr(:call, GlobalRef(Base, :sum), Expr(:vect, calls...)))
end