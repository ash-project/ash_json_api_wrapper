defmodule AshJsonApiWrapper.DataLayer.Transformers.SetEndpointDefaults do
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @impl Spark.Dsl.Transformer
  def transform(dsl) do
    base_entity_path = AshJsonApiWrapper.DataLayer.Info.base_entity_path(dsl)
    base_paginator = AshJsonApiWrapper.DataLayer.Info.base_paginator(dsl)
    base_fields = AshJsonApiWrapper.DataLayer.Info.fields(dsl) |> IO.inspect()

    dsl
    |> AshJsonApiWrapper.DataLayer.Info.endpoints()
    |> Enum.reduce({:ok, dsl}, fn endpoint, {:ok, dsl} ->
      endpoint_field_names = Enum.map(endpoint.fields, & &1.name)

      {:ok,
       Transformer.replace_entity(
         dsl,
         [:ash_json_api_wrapper, :endpoint],
         %{
           endpoint
           | entity_path: endpoint.entity_path || base_entity_path,
             paginator: endpoint.paginator || base_paginator,
             fields:
               Enum.reject(base_fields, &(&1.name in endpoint_field_names)) ++ endpoint.fields
         },
         &(&1.action == endpoint.action)
       )}
    end)
  end
end
