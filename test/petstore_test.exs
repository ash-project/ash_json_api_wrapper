defmodule AshJsonApiWrapper.Petstore.Test do
  use ExUnit.Case
  require Ash.Query

  @moduletag :petstore

  defmodule TestingTesla do
    use Tesla
    # plug Tesla.Middleware.Logger
  end

  defmodule Petstore.Order do
    use Ash.Resource, data_layer: AshJsonApiWrapper.DataLayer

    json_api_wrapper do
      tesla(TestingTesla)

      endpoints do
        base("https://petstore3.swagger.io/api/v3")

        endpoint :find_pets_by_status do
          path("/pet/findByStatus")
        end
      end

      fields do
        field :status do
          filter_handler(:simple)
        end
      end
    end

    actions do
      read(:find_pets_by_status) do
        primary? true
      end
    end

    attributes do
      attribute :id, :integer do
        primary_key?(true)
        allow_nil?(false)
      end

      # attribute(:category, :string) 
      attribute(:name, :string)
      attribute(:photo_urls, :string)

      attribute :status, :atom do
        constraints(one_of: [:available, :pending, :sold])
      end

      # attribute(:tags, :string)
    end
  end

  defmodule Api do
    @moduledoc false
    use Ash.Api

    resources do
      allow_unregistered?(true)
    end
  end

  test "it works" do
    Petstore.Order
    |> Ash.Query.filter(status == "pending")
    |> Api.read!()
  end
end
