defmodule AshJsonApiWrapper.Endpoint do
  defstruct [:action, :path, :entity_path, :fields, :fields_in, :write_entity_path]

  @type t :: %__MODULE__{}

  def schema do
    [
      action: [
        type: :atom,
        required: true,
        doc: "The action this path is for"
      ],
      path: [
        type: :string,
        default: "/",
        doc: "The path of the endpoint relative to the base, or an absolute path"
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
      ]
    ]
  end

  def default(path) do
    %__MODULE__{
      path: path,
      fields_in: :body
    }
  end
end
