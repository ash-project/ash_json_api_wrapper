# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApiWrapper.DefaultReq do
  @moduledoc """
  Builds the default Req client for API requests.
  """

  def new do
    Req.new(
      decode_body: false,
      redirect: true,
      retry: false
    )
  end
end
