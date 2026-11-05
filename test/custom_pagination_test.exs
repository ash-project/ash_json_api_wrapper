# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.CustomPagination.Test do
  use ExUnit.Case
  require Ash.Query
  import Mox
  @moduletag :custom_pagination

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  defmodule TestingReq do
    def new do
      AshJsonApiWrapper.DefaultReq.new()
      |> Req.merge(adapter: AshJsonApiWrapper.MockAdapter)
    end
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
      domain: AshJsonApiWrapper.CustomPagination.Test.Domain,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_domain_inclusion?: false

    json_api_wrapper do
      req(TestingReq)

      endpoints do
        base("https://65383945a543859d1bb1528e.mockapi.io/api/v1")

        endpoint :list_users do
          path("/users")
          limit_with {:param, "l"}
          runtime_sort? true
          paginator CustomPaginator
        end

        endpoint :create do
          path("/users")
          fields_in :body
        end

        endpoint :create_with_params do
          path("/users")
          fields_in :params
        end
      end
    end

    actions do
      read :list_users do
        primary?(true)

        pagination do
          offset?(true)
          required?(true)
          default_limit(50)
        end
      end

      create :create do
        accept [:id, :name]
      end

      create :create_with_params do
        accept [:id, :name]
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

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered?(true)
    end
  end

  # ── Test it! ──

  test "it works" do
    Application.put_env(:ash, :validate_api_resource_inclusion?, false)
    Application.put_env(:ash, :validate_api_config_inclusion?, false)

    AshJsonApiWrapper.MockAdapter
    |> expect(:run, 4, fn request ->
      params = URI.decode_query(request.url.query || "")

      body =
        case params do
          %{"l" => "3", "p" => "2"} ->
            "[]"

          %{"l" => "3", "p" => "1"} ->
            """
            [
              {"name": "Kendra Ernser", "id": "1"},
              {"name": "Max Hartman", "id": "2"},
              {"name": "John Benton", "id": "3"}
            ]
            """

          unexpected ->
            flunk("Unexpected query parameters: #{inspect(unexpected)}")
        end

      {request, Req.Response.new(status: 200, body: body)}
    end)

    users =
      Users
      |> Ash.Query.for_read(:list_users)
      # |> Ash.Query.limit(2)
      |> Ash.read!(page: [limit: 2, offset: 0])

    users2 =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Ash.read!(page: [limit: 2, offset: 1])

    assert Enum.map(users.results, & &1.id) == [1, 2]
    assert Enum.map(users2.results, & &1.id) == [2, 3]
  end

  test "forwards custom headers to the HTTP request" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      assert Req.Request.get_header(request, "authorization") ==
               ["Bearer test-token"]

      assert Req.Request.get_header(request, "x-request-id") ==
               ["req-migration-test"]

      {request, Req.Response.new(status: 200, body: "[]")}
    end)

    page =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Ash.Query.set_context(%{
        data_layer: %{
          headers: %{
            "authorization" => "Bearer test-token",
            "x-request-id" => "req-migration-test"
          }
        }
      })
      |> Ash.read!(page: [limit: 2, offset: 0])

    assert page.results == []
  end

  test "returns an error for an unsuccessful HTTP response" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      {request,
       Req.Response.new(
         status: 500,
         body: ~s({"error":"upstream unavailable"})
       )}
    end)

    result =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Ash.read(page: [limit: 2, offset: 0])

    assert {:error, error} = result
    assert Exception.message(error) =~ "Received status code 500"
  end

  test "create encodes attributes in the JSON body" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      # Preserve the existing HTTP method during this migration.
      assert request.method == :get
      assert request.url.path == "/api/v1/users"

      assert Jason.decode!(IO.iodata_to_binary(request.body)) ==
               %{"id" => 42, "name" => "Joe"}

      assert Req.Request.get_header(request, "content-type") ==
               ["application/json"]

      {request,
       Req.Response.new(
         status: 200,
         body: ~s({"id":"42","name":"Joe"})
       )}
    end)

    user =
      Users
      |> Ash.Changeset.for_create(:create, %{id: 42, name: "Joe"})
      |> Ash.create!()

    assert user.id == 42
    assert user.name == "Joe"
  end

  test "create can send attributes as query parameters" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      params = URI.decode_query(request.url.query || "")

      assert params["id"] == "43"
      assert params["name"] == "Joe"
      assert Jason.decode!(IO.iodata_to_binary(request.body)) == %{}

      {request,
       Req.Response.new(
         status: 200,
         body: ~s({"id":"43","name":"Joe"})
       )}
    end)

    user =
      Users
      |> Ash.Changeset.for_create(:create_with_params, %{id: 43, name: "Joe"})
      |> Ash.create!()

    assert user.id == 43
    assert user.name == "Joe"
  end

  test "returns an error when the HTTP connection times out" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      {request, %Req.TransportError{reason: :timeout}}
    end)

    result =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Ash.read(page: [limit: 2, offset: 0])

    assert {:error, error} = result
    assert Exception.message(error) =~ "timeout"
  end

  test "follows HTTP redirects" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      assert request.url.path == "/api/v1/users"

      {request,
       Req.Response.new(
         status: 302,
         headers: [{"location", "/api/v1/redirected-users"}],
         body: ""
       )}
    end)
    |> expect(:run, fn request ->
      assert request.url.path == "/api/v1/redirected-users"

      {request, Req.Response.new(status: 200, body: "[]")}
    end)

    page =
      Users
      |> Ash.Query.for_read(:list_users)
      |> Ash.read!(page: [limit: 2, offset: 0])

    assert page.results == []
  end

  test "allows custom retry configuration" do
    AshJsonApiWrapper.MockAdapter
    |> expect(:run, fn request ->
      {request, Req.Response.new(status: 429, body: "")}
    end)
    |> expect(:run, fn request ->
      {request, Req.Response.new(status: 200, body: "[]")}
    end)

    client =
      TestingReq.new()
      |> Req.merge(
        retry: fn _request, response_or_error ->
          match?(%Req.Response{status: 429}, response_or_error)
        end,
        max_retries: 1,
        retry_delay: fn _attempt -> 0 end,
        retry_log_level: false
      )

    assert {:ok, response} =
             Req.get(client, url: "https://example.test/users")

    assert response.status == 200
    assert response.body == "[]"
  end
end
