defmodule AshJsonApiWrapper.OpenApi.PetstoreTest do
  use ExUnit.Case
  require Ash.Query
  @moduletag :oapi_petstore

  @json "test/support/pet_store.json" |> File.read!() |> Jason.decode!()

  defmodule TestingTesla do
    use Tesla

    # plug(Tesla.Middleware.Headers, [
    #   {"authorization", "Bearer xxx"}
    # ])
  end

  @config [
    tesla: TestingTesla,
    endpoint: "https://petstore3.swagger.io/api/v3",
    resources: [
      Petstore: [
        path: "/store/order/{orderId}",
        object_type: "components.schemas.Order",
        primary_key: "id",
        # entity_path: "",
        fields: [
          orderId: [
            filter_handler: {:place_in_csv_list, ["id"]}
          ]
        ]
      ]
    ]
  ]

  test "it does stuff" do
    @json
    |> AshJsonApiWrapper.OpenApi.ResourceGenerator.generate(@config)
    |> Enum.map(fn {resource, code} ->
      Code.eval_string(code)
      resource
    end)
  end
end
