# SPDX-FileCopyrightText: 2021 ash_json_api_wrapper contributors <https://github.com/ash-project/ash_json_api_wrapper/graphs/contributors>
#
# SPDX-License-Identifier: MIT

import Config

# Explicit string-length behavior required by Ash.
config :ash, default_string_length_count: :codepoints

# Suppress Tesla builder deprecation warnings.
config :tesla, disable_deprecated_builder_warning: true

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshJsonApiWrapper.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_json_api_wrapper",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: [
      "README.md"
    ],
    version_tag_prefix: "v"
end
