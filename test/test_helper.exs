# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

ExUnit.start()
Mox.defmock(AshJsonApiWrapper.MockAdapter, for: Tesla.Adapter)
ExUnit.configure(exclude: [:hackernews])
