defmodule AshJsonApiWrapper.Hackernews.Test do
  use ExUnit.Case

  require Ash.Query

  @json "test/support/cybrid.json" |> File.read!() |> Jason.decode!()

  defmodule TestingTesla do
    use Tesla

    plug(Tesla.Middleware.Headers, [
      {"authorization",
       "Bearer eyJraWQiOiJTcWZRWXNjelFQbENOSDhxOXZuR1E2WWcwQk1ENm5UZkZMLWhxeER6eFdFIiwiYWxnIjoiUlM1MTIifQ.eyJpc3MiOiJodHRwczovL2lkLnNhbmRib3guY3licmlkLmFwcCIsImF1ZCI6WyJodHRwczovL2Jhbmsuc2FuZGJveC5jeWJyaWQuYXBwIiwiaHR0cDovL3NhbmRib3gtYXBpLWludGVybmFsLWtleTozMDA1IiwiaHR0cHM6Ly9pZC5zYW5kYm94LmN5YnJpZC5hcHAiLCJodHRwOi8vc2FuZGJveC1hcGktaW50ZXJuYWwtYWNjb3VudHM6MzAwMyIsImh0dHA6Ly9zYW5kYm94LWFwaS1pbnRlcm5hbC1pZGVudGl0eTozMDA0IiwiaHR0cDovL3NhbmRib3gtYXBpLWludGVncmF0aW9uLWV4Y2hhbmdlOjMwMDYiLCJodHRwOi8vc2FuZGJveC1hcGktaW50ZWdyYXRpb24tdHJhbnNmZXJzOjMwMDciXSwic3ViIjoiODVjZTljNDgxYjNiN2MwM2YwMTMxOTQ0MjVmODc5MmEiLCJzdWJfdHlwZSI6ImJhbmsiLCJzY29wZSI6WyJiYW5rczpyZWFkIiwiYmFua3M6d3JpdGUiLCJhY2NvdW50czpyZWFkIiwiYWNjb3VudHM6ZXhlY3V0ZSIsImN1c3RvbWVyczpyZWFkIiwiY3VzdG9tZXJzOndyaXRlIiwiY3VzdG9tZXJzOmV4ZWN1dGUiLCJwcmljZXM6cmVhZCIsInF1b3RlczpleGVjdXRlIiwicXVvdGVzOnJlYWQiLCJ0cmFkZXM6ZXhlY3V0ZSIsInRyYWRlczpyZWFkIiwidHJhbnNmZXJzOmV4ZWN1dGUiLCJ0cmFuc2ZlcnM6cmVhZCIsInJld2FyZHM6ZXhlY3V0ZSIsInJld2FyZHM6cmVhZCIsImV4dGVybmFsX2JhbmtfYWNjb3VudHM6cmVhZCIsImV4dGVybmFsX2JhbmtfYWNjb3VudHM6d3JpdGUiLCJleHRlcm5hbF9iYW5rX2FjY291bnRzOmV4ZWN1dGUiLCJleHRlcm5hbF93YWxsZXRzOnJlYWQiLCJleHRlcm5hbF93YWxsZXRzOmV4ZWN1dGUiLCJ3b3JrZmxvd3M6cmVhZCIsIndvcmtmbG93czpleGVjdXRlIiwiZGVwb3NpdF9hZGRyZXNzZXM6cmVhZCIsImRlcG9zaXRfYWRkcmVzc2VzOmV4ZWN1dGUiXSwiaWF0IjoxNjg4MTU4MTE4LCJleHAiOjE2ODgxODY5MTgsImp0aSI6Ijg0ODNhOTg3LWEzZjQtNGU4Mi1iODc3LTg5MDk4YTIyYWE4ZSIsInRva2VuX3R5cGUiOiJhY2Nlc3MiLCJwcm9wZXJ0aWVzIjp7InR5cGUiOiJzYW5kYm94In19.SVFHoZWIKP-owEYzOSfP53nW9oM068t5-CUkPUIlXWPmV_rPTNGhaqjdy9u7iZQvXZX2BF5_gJHx1QR91DBYoR0ftRHxsQTq4UsJChTPfIEZZPuA_lf2iOSy-ivtEdXgqGGHnuItxzS-NnadffSawNXK8Em2Dhfwq7eLps6KvE6fVGelpinvTbfMD7L9PbCdNLdoonEbkdG6eMDV8FEX0sDJhfEd_GUp_HzAKFZwiK_g7NTT4rgm_0Yp6Paue3_ZviDpEWCLhyQNxd-N2TlP4wQng3zafB9_JPX3Z-xKq2WU5z_VltOTHcCMrvsDhDA2oI1CgFT92LMQmC_3QlpCVyaN70Jpd2E-ON9TehQ6JjcNZXoiKl7YaoGDadrAOXdYacexvsNPRpxZhZYxKX3FWtUxYeg0mIHNSS3nd14kfBXVARIqGuBYzRjepmb49MJERNzdeQ-3YectmBVWsPFWfnuMZfWUW54yHR0EF-oWLJJhBqUaZTysyXWpLeKnTBb2t6Q0y9_GLltxZh4x44qRmaq7k511QkEcBbLOnR40HqwnoteCQs-Yqnc8nwHBZ8H6gkUWtQTDiu4_uOmqoqXDx9WDuX4z5pE4M8HzzC1nu7-KvCcqAaCgVQV_Nut0V_IwE-6vB3JOIbFLGjHGMK_WwOrCefKbLoH6ZN6v7wz0cuY"}
    ])
  end

  @config [
    tesla: TestingTesla,
    endpoint: "https://bank.sandbox.cybrid.app",
    resources: [
      "Cybrid.Account": [
        path: "/api/accounts",
        object_type: "components.schemas.Account",
        primary_key: "guid",
        entity_path: "objects",
        fields: [
          guid: [
            filter_handler: {:place_in_list, ["guid"]}
            # {
            #   "name": "guid",
            #   "in": "query",
            #   "required": false,
            #   "description": "Comma separated account_guids to list accounts for.",
            #   "schema": {
            #     "type": "string"
            #   }
            # },
            # {
            #   "name": "bank_guid",
            #   "in": "query",
            #   "required": false,
            #   "description": "Comma separated bank_guids to list accounts for.",
            #   "schema": {
            #     "type": "string"
            #   }
            # },
            # {
            #   "name": "customer_guid",
            #   "in": "query",
            #   "required": false,
            #   "description": "Comma separated customer_guids to list accounts for.",
            #   "schema": {
            #     "type": "string"
            #   }
            # }
          ]
        ]
      ]
    ]
  ]

  defmodule Api do
    use Ash.Api

    resources do
      allow_unregistered? true
    end
  end

  test "it does stuff" do
    @json
    |> AshJsonApiWrapper.OpenApi.ResourceGenerator.generate(@config)
    |> Enum.map(fn {resource, code} ->
      IO.puts(code)
      Code.eval_string(code)
      resource
    end)

    Cybrid.Account
    |> Ash.Query.for_read(:list_accounts)
    |> Ash.Query.filter(guid == "1c96166bfa20e434962d6f08a96e69ad")
    # |> Ash.Query.filter(type == :fee)
    |> Api.read!()
    |> IO.inspect()
  end
end
