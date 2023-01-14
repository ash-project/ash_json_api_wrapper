defmodule AshJsonApiWrapper.DataLayer.Transformers.SetEndpointDefaults do
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    base_entity_path = AshJsonApiWrapper.DataLayer.Info.base_entity_path(dsl) || nil

    dsl
    |> AshJsonApiWrapper.DataLayer.Info.endpoints()
    |> Enum.reduce({:ok, dsl}, fn endpoint, {:ok, dsl} ->
      if endpoint.entity_path || is_nil(base_entity_path) do
        {:ok, dsl}
      else
        {:ok,
         Transformer.replace_entity(
           dsl,
           [:ash_json_api_wrapper, :endpoint],
           %{
             endpoint
             | entity_path: base_entity_path
           },
           &(&1.action == endpoint.action)
         )}
      end
    end)
  end
end
