defmodule AshJsonApiWrapper.CustomPagination.Test do
  use ExUnit.Case
  require Ash.Query
  @moduletag :custom_pagination

  # ── Custom paginator ──

  defmodule CustomPaginator do
    use AshJsonApiWrapper.Paginator

    def cursor() do
      case :ets.whereis(:cursor) do
        :undefined ->
          :ets.new(:cursor, [:set, :protected, :named_table])
          |> :ets.insert({self(), 1})
          1

        _ ->
          [{_, value} | _rest] = :ets.lookup(:cursor, self())
          value
      end
    end

    def increment_cursor() do
      :ets.insert(:cursor, {self(), cursor() + 1})
    end

    def reset_cursor() do
      :ets.insert(:cursor, {self(), 1})
    end

    def continue(_response, [], _) do
      reset_cursor()
      :halt
    end

    def continue(_response, _entities, _opts) do
      increment_cursor()
      {:ok, %{params: %{:p => cursor()}}}
    end
  end

  # ── Resource ──

  defmodule Users do
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_api_inclusion?: false

    json_api_wrapper do
      tesla(Tesla)

      endpoints do
        base("https://65383945a543859d1bb1528e.mockapi.io/api/v1")

        endpoint :list_users do
          path("/users")
          limit_with {:param, "l"}
          runtime_sort? true
          paginator CustomPaginator
        end
      end
    end

    actions do
      read(:list_users) do
        primary?(true)

        pagination do
          offset?(true)
          required?(true)
          default_limit(50)
        end
      end
    end

    attributes do
      attribute :id, :integer do
        primary_key?(true)
        allow_nil?(false)
      end

      attribute(:name, :string)
    end
  end

  defmodule Api do
    use Ash.Api, validate_config_inclusion?: false

    resources do
      allow_unregistered?(true)
    end
  end

  # ── Test it! ──

  test "it works" do
    Application.put_env(:ash, :validate_api_resource_inclusion?, false)
    Application.put_env(:ash, :validate_api_config_inclusion?, false)

    users =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Api.read!(page: [limit: 99])

    user_count = users.results |> Enum.count()

    assert(user_count == 99)
  end
end
