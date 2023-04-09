defmodule CozyProxy do
  @moduledoc """
  Proxy requests to other plugs.

  ## Usage

  Set base configurations within config files:

      config :demo_app, CozyProxy,
        [
          http: [port: 8080],
          backends: [
            %{
              plug: SubAppWeb.Endpoint,
              domain: "site1.example.com"
            },
            %{
              plug: {DemoPlug, []},
              domain: "site2.example.com"
            }
          ]
        ]

  `CozyProxy` instances are isolated supervision trees and you can include it in application's supervisor.

  Use the application configuration you've just set and include `CozyProxy` in the list of supervised children:

      # lib/demo_app/application.ex
      def start(_type, _args) do
        children = [
          # ...
          {CozyProxy, Application.fetch_env!(:demo_app, CozyProxy)}
        ]

        opts = [strategy: :one_for_one, name: Closet.Supervisor]
        Supervisor.start_link(children, opts)
      end

  When using `CozyProxy`, it's better to configure Phoenix endpoints to not start servers, in order to avoid Phoenix endpoints bypassing `CozyProxy`:

      config :demo_app, SubAppWeb.Endpoint, server: false

  ## Available options of configuration

  - `:http` - the configuration for the HTTP server. It accepts all options as defined by [Plug.Cowboy](https://hexdocs.pm/plug_cowboy/).
  - `:https` - the configuration for the HTTPS server. It accepts all options as defined by [Plug.Cowboy](https://hexdocs.pm/plug_cowboy/).
  - `:server` - `true` by default. If you are running the application with `mix phx.server`, this option is ignored, and the server will always be started.
  - `:backends` - the configuration of backends:
    - `:plug`
    - `:domain`
    - `:verb`
    - `:host`
    - `:path`

  """

  use Supervisor
  require Logger
  alias CozyProxy.Config
  alias CozyProxy.Dispatcher

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    config = Config.new!(init_arg)

    start_server? = config.server || is_phoenix_on?()

    children =
      if start_server?,
        do: build_children(config),
        else: []

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Consinder Phoenix is on when meets following cases:
  #
  # + run `iex -S mix phx.server`
  # + run `mix phx.server`
  #
  defp is_phoenix_on?() do
    Application.get_env(:phoenix, :serve_endpoints, false)
  end

  defp build_children(%Config{} = config) do
    supported_schemes = [:http, :https]

    children = []

    Enum.reduce(supported_schemes, children, fn scheme, children ->
      if options = Map.get(config, scheme) do
        # credo:disable-for-next-line Credo.Check.Refactor.Nesting
        Logger.info(fn -> gen_listen_info(scheme, options) end)
        [build_child(scheme, options, config.backends) | children]
      else
        children
      end
    end)
  end

  defp gen_listen_info(scheme, options) do
    default_ip = {0, 0, 0, 0}
    ip = Keyword.get(options, :ip, default_ip)
    port = Keyword.get(options, :port)
    "#{inspect(__MODULE__)} is listening on #{scheme}://#{:inet.ntoa(ip)}:#{port}"
  end

  defp build_child(scheme, options, backends) do
    {
      Plug.Cowboy,
      scheme: scheme, plug: {Dispatcher, [backends: backends]}, options: options
    }
  end
end
