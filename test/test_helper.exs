# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

ExUnit.start()
Mox.defmock(AshJsonApiWrapper.MockAdapter, for: Tesla.Adapter)
ExUnit.configure(exclude: [:hackernews])
