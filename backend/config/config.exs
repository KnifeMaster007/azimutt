# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :azimutt,
  business_name: "Azimutt",
  seo_title: "Azimutt · Database explorer and analyzer",
  seo_description: "Next-Gen ERD: Design, Explore, Document and Analyze your database.",
  seo_keywords:
    "SQL,schema,database,entity relationship diagram,data analyst,schema explorer,schema analyzer,DDL,DBA,database schema,database diagram,explore,understand,visualization",
  mailer_default_from_name: "Support",
  logo_url_for_emails: "https://azimutt.app/android-chrome-512x512.png",
  cli_url: "https://www.npmjs.com/package/azimutt",
  heroku_url: "https://elements.heroku.com/addons/azimutt",
  browser_extension_url: "https://chrome.google.com/webstore/detail/azimutt/bpifdkechgdibghkkpaioccoijeoebjf",
  documentation_url: "https://docs.azimutt.app",
  github_url: "https://github.com/azimuttapp/azimutt",
  github_issues: "https://github.com/azimuttapp/azimutt/issues",
  github_new_issue: "https://github.com/azimuttapp/azimutt/issues/new",
  twitter_url: "https://twitter.com/azimuttapp",
  linkedin_url: "https://www.linkedin.com/company/azimuttapp",
  slack_url: "https://join.slack.com/t/azimutt/shared_invite/zt-1pumru3pj-iBKIq7f~7ADOfySuxuFA2Q",
  pro_plan_seat_price: 13,
  free_plan_seats: 3,
  # MUST stay in sync with frontend/src/Conf.elm (`features`)
  free_plan_layouts: 3,
  free_plan_memos: 5,
  free_plan_colors: false,
  free_plan_private_links: true,
  free_plan_sql_export: false,
  free_plan_db_analysis: false,
  free_plan_db_access: false,
  environment: config_env(),
  version: "2.0.#{DateTime.to_unix(DateTime.utc_now())}",
  commit_hash: System.cmd("git", ["log", "-1", "--pretty=format:%h"]) |> elem(0) |> String.trim(),
  commit_message: System.cmd("git", ["log", "-1", "--pretty=format:%s"]) |> elem(0) |> String.trim(),
  commit_date: System.cmd("git", ["log", "-1", "--pretty=format:%aI"]) |> elem(0) |> String.trim(),
  commit_author: System.cmd("git", ["log", "-1", "--pretty=format:%an"]) |> elem(0) |> String.trim()

config :azimutt,
  ecto_repos: [Azimutt.Repo]

config :azimutt, Azimutt.Repo, migration_primary_key: [type: :uuid]

config :azimutt, Azimutt.Repo, migration_timestamps: [type: :utc_datetime_usec, inserted_at: :created_at]

# Configures the endpoint
config :azimutt, AzimuttWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: AzimuttWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Azimutt.PubSub,
  live_view: [signing_salt: "eIPt31PL"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :tailwind,
  version: "3.0.24",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :ueberauth, Ueberauth,
  providers: [
    # see https://docs.github.com/en/developers/apps/building-oauth-apps/scopes-for-oauth-apps
    github: {Ueberauth.Strategy.Github, [default_scope: "read:user,user:email"]}
  ]

config :azimutt, AzimuttWeb.Storybook,
  content_path: Path.expand("../lib/azimutt_web/storybook/", __DIR__),
  css_path: "/assets/app.css",
  js_path: "/assets/app.js",
  title: "Azimutt Storybook"

config :azimutt, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: AzimuttWeb.Router,
      # (optional) endpoint config used to set host, port and https schemes.
      endpoint: AzimuttWeb.Endpoint
    ]
  }

config :phoenix_swagger, json_library: Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
