# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

ExUnit.start()

defmodule AshJsonApiWrapper.TestAdapter do
  @callback run(Req.Request.t()) ::
              {Req.Request.t(), Req.Response.t() | Exception.t()}
end

Mox.defmock(
  AshJsonApiWrapper.MockAdapter,
  for: AshJsonApiWrapper.TestAdapter
)
