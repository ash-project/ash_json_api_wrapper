defmodule AshJsonApiWrapper.CustomPagination.Test do
  use ExUnit.Case
  require Ash.Query
  import Mox
  @moduletag :custom_pagination

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  defmodule TestingTesla do
    use Tesla

    adapter(AshJsonApiWrapper.MockAdapter)
    # plug(Tesla.Middleware.Logger)

    plug(Tesla.Middleware.Retry,
      delay: 2000,
      max_retries: 5,
      max_delay: 4_000,
      should_retry: fn
        {:ok, %{status: status}} when status in [429] -> true
        {:ok, _} -> false
        {:error, _} -> true
      end
    )
  end

  # ── Custom paginator ──

  defmodule CustomPaginator do
    use AshJsonApiWrapper.Paginator

    defp cursor do
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

    defp increment_cursor do
      :ets.insert(:cursor, {self(), cursor() + 1})
    end

    defp reset_cursor do
      cursor()
      :ets.insert(:cursor, {self(), 1})
    end

    def start(_opts) do
      reset_cursor()
      {:ok, %{params: %{"p" => 1}}}
    end

    def continue(_response, [], _) do
      :halt
    end

    def continue(_response, _entities, _opts) do
      increment_cursor()
      {:ok, %{params: %{"p" => cursor()}}}
    end
  end

  # ── Resource ──

  defmodule Users do
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_api_inclusion?: false

    json_api_wrapper do
      tesla(TestingTesla)

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

    AshJsonApiWrapper.MockAdapter
    |> expect(:call, 4, fn env, _options ->
      case env.query do
        %{"l" => 3, "p" => 2} ->
          {:ok, %Tesla.Env{env | status: 200, body: "[]"}}

        %{"l" => 3, "p" => 1} ->
          {:ok,
           %Tesla.Env{
             env
             | status: 200,
               body: """
               [
                {"name": "Kendra Ernser", "id":"1"},
                {"name": "Max Hartman", "id":"2"},
                {"name": "John Benton", "id":"3"}
               ]
               """
           }}

        query ->
          {:ok,
           %Tesla.Env{
             env
             | status: 500,
               body: "Unexpected parameters: #{query |> Kernel.inspect()}"
           }}
      end
    end)

    users =
      Users
      |> Ash.Query.for_read(:list_users)
      # |> Ash.Query.limit(2)
      |> Api.read!(page: [limit: 2, offset: 0])

    users2 =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Api.read!(page: [limit: 2, offset: 1])

    users_count = users.results |> Enum.count()
    users2_count = users2.results |> Enum.count()

    assert(users_count == users2_count)
  end
end
