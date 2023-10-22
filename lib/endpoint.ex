defmodule AshJsonApiWrapper.Endpoint do
  defstruct [
    :action,
    :path,
    :entity_path,
    :fields,
    :fields_in,
    :write_entity_path,
    :get_for,
    :runtime_sort?,
    :limit_with,
    :paginator,
    :__identifier__
  ]

  @type t :: %__MODULE__{}

  def schema do
    [
      action: [
        type: {:wrap_list, :atom},
        required: true,
        doc: "The action this path is for"
      ],
      path: [
        type: :string,
        default: "/",
        doc: "The path of the endpoint relative to the base, or an absolute path"
      ],
      limit_with: [
        type: :any,
        doc: "To provide query limits as endpoint query params, use `{:param, \"param_name\"}`"
      ],
      fields_in: [
        type: {:in, [:body, :params]},
        default: :body,
        doc: "Where to place the fields when writing them."
      ],
      write_entity_path: [
        type: {:list, :string},
        doc:
          "The list path at which the entity should be placed in the body when creating/updating."
      ],
      entity_path: [
        type: :string,
        doc: "A json path at which the entities can be read back from the response"
      ],
      runtime_sort?: [
        type: :boolean,
        default: false,
        doc:
          "Whether or not this endpoint should support sorting at runtime after the data has been received."
      ],
      paginator: [
        type:
          {:spark_behaviour, AshJsonApiWrapper.Paginator, AshJsonApiWrapper.Paginator.Builtins},
        doc:
          "A module implementing the `AshJSonApiWrapper.Paginator` behaviour, to allow scanning pages when reading."
      ]
    ]
  end

  def get_schema do
    Keyword.merge(
      schema(),
      get_for: [
        type: :atom,
        doc: """
        Signifies that this endpoint is a get endpoint for a given field.

        See the docs of `get_endpoint` for more.
        """
      ]
    )
  end

  def default(resource) do
    %__MODULE__{
      path: AshJsonApiWrapper.DataLayer.Info.endpoint_base(resource),
      entity_path: AshJsonApiWrapper.DataLayer.Info.base_entity_path(resource),
      paginator: AshJsonApiWrapper.DataLayer.Info.base_paginator(resource),
      fields: AshJsonApiWrapper.DataLayer.Info.fields(resource),
      fields_in: :body
    }
  end
end
