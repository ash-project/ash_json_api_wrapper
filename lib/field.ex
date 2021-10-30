defmodule AshJsonApiWrapper.Field do
  defstruct [:name, :path, :write_path]

  @type t :: %__MODULE__{}

  def schema do
    [
      name: [
        type: :atom,
        required: true,
        doc: "The attribute this field is configuring"
      ],
      path: [
        type: :string,
        doc: "The path of the value for this field, relative to the entity's path"
      ],
      write_path: [
        type: {:list, :string},
        doc: "The list path of the value for this field when writing."
      ]
    ]
  end
end
