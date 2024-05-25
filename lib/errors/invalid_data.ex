defmodule AshJsonApiWrapper.Errors.InvalidData do
  @moduledoc "Used when an invalid value is present in the response for a given attribute"

  use Splode.Error, fields: [:field, :value], class: :invalid

  def message(error) do
    "Invalid value provided#{for_field(error)}: #{inspect(error.value)}"
  end

  defp for_field(%{field: field}) when not is_nil(field), do: " for #{field}"
  defp for_field(_), do: ""
end
