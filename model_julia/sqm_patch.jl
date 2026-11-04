# Temporary SquareModels 0.10.0 patch: copy() returning ModelDictionary{Any}.
# Julia sometimes mis-dispatches the pattern `Dictionary{String,Union{Nothing,T}} where T`
# (no match, or T = Any). Take T from the dictionary's element type instead.
# Include once, after `using SquareModels`. Remove when fixed upstream.
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