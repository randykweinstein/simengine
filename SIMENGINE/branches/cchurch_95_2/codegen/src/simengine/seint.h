const simengine_interface seint = {
  model_name,
  target,
  solver_names,
  iterator_names,
  input_names,
  state_names,
  output_names,
  default_inputs,
  default_states,
  output_num_quantities,
  VERSION,
  sizeof(CDATAFORMAT),
  PARALLEL_MODELS,
  NUM_ITERATORS,
  NUM_INPUTS,
  NUM_STATES,
  NUM_OUTPUTS,
  HASHCODE
};

simengine_alloc se_alloc = { malloc, realloc, free };
