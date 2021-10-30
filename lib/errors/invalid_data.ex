defmodule AshJsonApiWrapper.Errors.InvalidData do
  @moduledoc "Used when an invalid value is present in the response for a given attribute"
  use Ash.Error.Exception

  def_ash_error([:field, :value], class: :invalid)

  defimpl Ash.ErrorKind do
    def id(_), do: Ash.UUID.generate()

    def code(_), do: "invalid_data"

    def message(error) do
      "Invalid value provided#{for_field(error)}: #{inspect(error.value)}"
    end

    defp for_field(%{field: field}) when not is_nil(field), do: " for #{field}"
    defp for_field(_), do: ""
  end
end
