spark_locals_without_parens = [
  base: 1,
  base_entity_path: 1,
  base_paginator: 1,
  endpoint: 1,
  endpoint: 2,
  entity_path: 1,
  field: 1,
  field: 2,
  fields_in: 1,
  filter_handler: 1,
  get_endpoint: 2,
  get_endpoint: 3,
  limit_with: 1,
  paginator: 1,
  path: 1,
  runtime_sort?: 1,
  tesla: 1,
  write_entity_path: 1,
  write_path: 1
]

[
  import_deps: [:ash],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
