defmodule AshJsonApiWrapper.Hackernews.Test do
  use ExUnit.Case

  @moduletag :hackernews

  defmodule TopStory do
    @moduledoc false
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_api_inclusion?: false

    json_api_wrapper do
      endpoints do
        base "https://hacker-news.firebaseio.com/v0/"

        endpoint :read do
          limit_with {:param, "limitToFirst"}
          path "topstories.json"
        end
      end

      fields do
        field :id do
          path ""
        end
      end
    end

    attributes do
      integer_primary_key(:id)
    end

    actions do
      defaults([:read])
    end

    relationships do
      has_one :story, AshJsonApiWrapper.Hackernews.Test.Story do
        source_attribute(:id)
        destination_attribute(:id)
      end
    end
  end

  defmodule ShortUrl do
    @moduledoc false
    use Ash.Calculation

    def calculate(records, _, _) do
      Enum.map(records, fn record ->
        URI.parse(record.url)
        |> Map.put(:path, nil)
        |> Map.put(:scheme, nil)
        |> Map.put(:query, nil)
        |> to_string()
      end)
    end
  end

  defmodule Story do
    @moduledoc false
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_api_inclusion?: false

    calculations do
      calculate(:short_url, :string, ShortUrl)
    end

    preparations do
      prepare(build(load: :short_url))
    end

    attributes do
      integer_primary_key(:id)

      attribute :by, :string do
        allow_nil?(false)
      end

      attribute :score, :integer do
        allow_nil?(false)
      end

      attribute(:title, :string)
      attribute(:body, :string)
      attribute(:url, :string)
    end

    json_api_wrapper do
      endpoints do
        base "https://hacker-news.firebaseio.com/v0/"

        get_endpoint :read, :id do
          path "item/:id.json"
        end
      end
    end

    actions do
      defaults([:read])
    end

    relationships do
      has_one :user, AshJsonApiWrapper.Hackernews.Test.User do
        source_attribute(:by)
        destination_attribute(:id)
      end
    end
  end

  defmodule User do
    @moduledoc false
    use Ash.Resource,
      data_layer: AshJsonApiWrapper.DataLayer,
      validate_api_inclusion?: false

    attributes do
      attribute :id, :string do
        primary_key?(true)
        allow_nil?(false)
      end
    end

    json_api_wrapper do
      endpoints do
        base "https://hacker-news.firebaseio.com/v0/"

        get_endpoint :read, :id do
          path "user/:id.json"
        end
      end

      fields do
        field :id do
          path "id"
        end
      end
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Api do
    @moduledoc false
    use Ash.Api, validate_config_inclusion?: false

    resources do
      allow_unregistered?(true)
    end
  end

  test "it works" do
    assert [top_story] =
             TopStory
             |> Ash.Query.limit(1)
             |> Ash.Query.load(story: :user)
             |> Api.read!()
             |> Enum.map(& &1.story)

    assert is_binary(top_story.url)
    assert is_binary(top_story.title)
    assert is_binary(top_story.user.id)
    assert top_story.by == top_story.user.id
  end
end
