defmodule AshJsonApiWrapper do
  @moduledoc """
  """

  alias Ash.Dsl.Extension

  @spec endpoint_base(Ash.Resource.t()) :: String.t() | nil
  def endpoint_base(resource) do
    Extension.get_opt(resource, [:json_api_wrapper, :endpoints], :base, nil, false)
  end

  @spec finch(Ash.Resource.t()) :: module | nil
  def finch(resource) do
    Extension.get_opt(resource, [:json_api_wrapper], :finch, nil, false)
  end

  @spec before_request(Ash.Resource.t()) :: module | nil
  def before_request(resource) do
    Extension.get_opt(resource, [:json_api_wrapper], :before_request, nil, false)
  end

  @spec field(Ash.Resource.t(), atom) :: AshJsonApiWrapper.Field.t() | nil
  def field(resource, name) do
    resource
    |> fields()
    |> Enum.find(&(&1.name == name))
  end

  @spec fields(Ash.Resource.t()) :: list(AshJsonApiWrapper.Field.t())
  def fields(resource) do
    Extension.get_entities(resource, [:json_api_wrapper, :fields])
  end

  @spec endpoint(Ash.Resource.t(), atom) :: AshJsonApiWrapper.Endpoint.t() | nil
  def endpoint(resource, action) do
    default_endpoint = AshJsonApiWrapper.Endpoint.default(endpoint_base(resource))

    resource
    |> Extension.get_entities([:json_api_wrapper, :endpoints])
    |> Enum.find(&(&1.action == action))
    |> case do
      nil ->
        default_endpoint
      endpoint ->
        if default_endpoint.path && endpoint.path do
          %{endpoint | path: default_endpoint.path <> endpoint.path}
        else
          %{endpoint | path: endpoint.path || default_endpoint.path}
        end
    end
  end

  @spec endpoints(Ash.Resource.t()) :: list(AshJsonApiWrapper.Endpoint.t())
  def endpoints(resource) do
    Extension.get_entities(resource, [:json_api_wrapper, :endpoints])
  end

  @spec set_body_param(query_or_changeset, String.t(), any) :: query_or_changeset
        when query_or_changeset: Ash.Query.t() | Ash.Changeset.t()
  def set_body_param(query, key, value) do
    new_context =
      query.context
      |> Map.put_new(:data_layer, %{})
      |> Map.update!(:data_layer, fn data_layer ->
        data_layer
        |> Map.put_new(:body, %{})
        |> Map.update!(:body, &Map.put(&1, key, value))
      end)

    %{query | context: new_context}
  end

  @spec merge_query_params(query_or_changeset, map) :: query_or_changeset
        when query_or_changeset: Ash.Query.t() | Ash.Changeset.t()
  def merge_query_params(%Ash.Query{} = query, params) do
    Ash.Query.set_context(query, %{data_layer: %{query_params: params}})
  end

  def merge_query_params(%Ash.Changeset{} = changeset, params) do
    Ash.Changeset.set_context(changeset, %{data_layer: %{query_params: params}})
  end

  @spec set_query_params(query_or_changeset, map) :: query_or_changeset
        when query_or_changeset: Ash.Query.t() | Ash.Changeset.t()
  def set_query_params(query, params) do
    new_context =
      query.context
      |> Map.put_new(:data_layer, %{})
      |> Map.update!(:data_layer, fn data_layer ->
        Map.put(data_layer, :query_params, params)
      end)

    %{query | context: new_context}
  end
end
