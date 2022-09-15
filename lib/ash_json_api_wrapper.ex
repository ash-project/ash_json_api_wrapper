defmodule AshJsonApiWrapper do
  @moduledoc """
  """

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
