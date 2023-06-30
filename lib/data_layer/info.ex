defmodule AshJsonApiWrapper.DataLayer.Info do
  @moduledoc "Introspection helpers for AshJsonApiWrapper.DataLayer"

  alias Spark.Dsl.Extension

  @spec endpoint_base(map | Ash.Resource.t()) :: String.t() | nil
  def endpoint_base(resource) do
    Extension.get_opt(resource, [:json_api_wrapper, :endpoints], :base, nil, false)
  end

  @spec tesla(map | Ash.Resource.t()) :: module | nil
  def tesla(resource) do
    Extension.get_opt(
      resource,
      [:json_api_wrapper],
      :tesla,
      AshJsonApiWrapper.DefaultTesla,
      false
    )
  end

  @spec base_entity_path(map | Ash.Resource.t()) :: String.t() | nil
  def base_entity_path(resource) do
    Extension.get_opt(resource, [:json_api_wrapper], :base_entity_path, nil, false)
  end

  @spec base_paginator(map | Ash.Resource.t()) :: AshJsonApiWrapper.Paginator.ref()
  def base_paginator(resource) do
    Extension.get_opt(resource, [:json_api_wrapper], :base_paginator, nil, false)
  end

  @spec field(map | Ash.Resource.t(), atom) :: AshJsonApiWrapper.Field.t() | nil
  def field(resource, name) do
    resource
    |> fields()
    |> Enum.find(&(&1.name == name))
  end

  @spec fields(map | Ash.Resource.t()) :: list(AshJsonApiWrapper.Field.t())
  def fields(resource) do
    Extension.get_entities(resource, [:json_api_wrapper, :fields])
  end

  @spec endpoint(map | Ash.Resource.t(), atom) :: AshJsonApiWrapper.Endpoint.t() | nil
  def endpoint(resource, action) do
    default_endpoint = AshJsonApiWrapper.Endpoint.default(resource)

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

  @spec get_endpoint(map | Ash.Resource.t(), atom, atom) :: AshJsonApiWrapper.Endpoint.t() | nil
  def get_endpoint(resource, action, get_for) do
    default_endpoint = AshJsonApiWrapper.Endpoint.default(resource)

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

  @spec endpoints(map | Ash.Resource.t()) :: list(AshJsonApiWrapper.Endpoint.t())
  def endpoints(resource) do
    Extension.get_entities(resource, [:json_api_wrapper, :endpoints])
  end
end
