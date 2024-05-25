defmodule AshJsonApiWrapper.Petstore.Test do
  use ExUnit.Case
  require Ash.Query
  @moduletag :petstore

  defmodule TestingTesla do
    use Tesla
    # plug Tesla.Middleware.Logger
  end

  defmodule Petstore do
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      domain: AshJsonApiWrapper.Petstore.Test.Domain,
      validate_domain_inclusion?: false

    json_api_wrapper do
      tesla(TestingTesla)

      endpoints do
        base("https://petstore3.swagger.io/api/v3")

        endpoint [:find_pets_by_status, :by_status] do
          path("/pet/findByStatus")

          field :status do
            filter_handler(:simple)
          end
        end

        get_endpoint :pet, :id do
          path("/pet/:id")
        end
      end

      fields do
      end
    end

    actions do
      read(:find_pets_by_status) do
        primary? false
      end

      read(:by_status) do
        primary? true
      end

      read(:pet) do
        primary? false
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

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered?(true)
    end
  end

  test "it works" do
    Petstore
    |> Ash.Query.for_read(:find_pets_by_status)
    |> Ash.Query.filter(status == "pending")
    |> Ash.read!()

    Petstore
    |> Ash.Query.for_read(:by_status)
    |> Ash.Query.filter(status == "available")
    |> Ash.read!()

    Petstore
    |> Ash.Query.for_read(:pet)
    |> Ash.Query.filter(id == 10)
    |> Ash.read!()
  end
end
