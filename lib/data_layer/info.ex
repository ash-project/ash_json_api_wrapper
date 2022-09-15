defmodule AshJsonApiWrapper.DataLayer.Info do
  @moduledoc "Introspection helpers for AshJsonApiWrapper.DataLayer"

  alias Spark.Dsl.Extension

  @spec endpoint_base(Ash.Resource.t()) :: String.t() | nil
  def endpoint_base(resource) do
    Extension.get_opt(resource, [:json_api_wrapper, :endpoints], :base, nil, false)
  end

  @spec finch(Ash.Resource.t()) :: module | nil
  def finch(resource) do
    Extension.get_opt(resource, [:json_api_wrapper], :finch, nil, false)
  end

  @spec before_request(Ash.Resource.t()) :: (Finch.Request.t() -> Finch.Request.t()) | nil
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
    |> Enum.reject(& &1.get_for)
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

  @spec get_endpoint(Ash.Resource.t(), atom, atom) :: AshJsonApiWrapper.Endpoint.t() | nil
  def get_endpoint(resource, action, get_for) do
    default_endpoint = AshJsonApiWrapper.Endpoint.default(endpoint_base(resource))

    resource
    |> Extension.get_entities([:json_api_wrapper, :endpoints])
    |> Enum.find(fn endpoint ->
      endpoint.action == action && endpoint.get_for == get_for
    end)
    |> case do
      nil ->
        nil

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
end
