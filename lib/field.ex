defmodule AshJsonApiWrapper.Field do
  defstruct [:name, :path, :write_path, :filter_handler]

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
      ],
      filter_handler: [
        type: :any,
        doc: """
        Specification for how the field is handled when used in filters. This is relatively limited at the moment.

        Supports the following:
        * `:simple` - Sets the value directly into the query params.
        * `{:simple, "key" | ["path", "to", "key"]}` - Sets the value directly into the query params using the provided key.
        * `{:place_in_list, ["path", "to", "list"]}` - Supports `or equals` and `in` filters over the given field, by placing their values in the provided list.
        """
      ]
    ]
  end
end
