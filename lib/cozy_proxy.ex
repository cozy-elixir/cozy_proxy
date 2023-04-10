defmodule CozyProxy do
  @moduledoc """
  Proxy requests to other plugs.

  ## Usage

  `CozyProxy` instances are isolated supervision trees and you can include it in application's
  supervisor:

      # lib/demo/application.ex
      def start(_type, _args) do
        children = [
          # ...
          {CozyProxy, Application.fetch_env!(:demo, CozyProxy)}
        ]

        opts = [strategy: :one_for_one, name: Demo.Supervisor]
        Supervisor.start_link(children, opts)
      end

  Above code requires a piece of configuration:

      config :demo, CozyProxy,
        http: [port: 8080],
        backends: [
          %{
            plug: HealthCheckPlug,
            path: "/health-check"
          },
          %{
            plug: DemoWebAPI.Endpoint,
            path: "/api"
          },
          %{
            plug: DemoAdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: DemoWeb.Endpoint,
            path: "/"
          }
        ]

  When using `CozyProxy`, it's better to configure Phoenix endpoints to not start servers, in
  order to avoid Phoenix endpoints bypassing `CozyProxy`:

      config :demo, DemoWeb.Endpoint, server: false
      config :demo, DemoWebAPI.Endpoint, server: false
      config :demo, DemoAdminWeb.Endpoint, server: false

  ## Configurations

    * `:http` - the configuration for the HTTP server. It accepts all options as defined by
      [Plug.Cowboy](https://hexdocs.pm/plug_cowboy/).
    * `:https` - the configuration for the HTTPS server. It accepts all options as defined by
      [Plug.Cowboy](https://hexdocs.pm/plug_cowboy/).
    * `:server` - `false` by default. It can be aware of Phoenix startup arguments, if you are
      running the application with `mix phx.server` or `iex -S mix phx.server`, this option will
      be always considered as `true`.
    * `:backends` - the configuration of backends. See next section for more details.

  ### about `:backends`

  A valid configuration of `:backends` is a list of maps, and the keys of maps are:

    * `:plug`:
      * required
      * typespec: `module() | {module(), keyword()}`
      * examples:
        * `HealthCheckPlug`
        * `{HealthCheckPlug, []}`
        * ...
    * `:method`:
      * optional
      * typespec: `String.t()`
      * examples:
        * `"GET"`
        * `"POST"`
        * ...
    * `:host`:
      * optional
      * typespec: `String.t()`
      * examples:
        * `"example.com"`
        * ...
    * `:path`:
      * optional
      * typespec: `String.t()`
      * examples:
        * `"/admin"`
        * `"/api"`
        * ...

  ## Notes

  ### Rewritting path

  If there's a backend like this:

      %Backend{
        plug: ...,
        method: nil,
        host: nil,
        path: "/api"
      }

  When the backend is matched, the request path like `/api/v1/users` will be rewritten as
  `/v1/users`.

  ### The order of backends matters

  If you configure the backends like this:

      config :demo, CozyProxy,
        backends: [
          %{
            plug: DemoUserWeb.Endpoint,
            path: "/"
          },
          %{
            plug: DemoUserAPI.Endpoint,
            path: "/api"
          },
          %{
            plug: DemoAdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: HealthCheck,
            path: "/health-check"
          }
        ]

  The first backend will always match, which may not what you expected.

  If you want all backends to have a chance to match, you should configure them like this:

      config :demo, CozyProxy,
        backends: [
          %{
            plug: HealthCheck,
            path: "/health-check"
          },
          %{
            plug: DemoUserAPI.Endpoint,
            path: "/api"
          },
          %{
            plug: DemoAdminWeb.Endpoint,
            path: "/admin"
          },
          %{
            plug: DemoUserWeb.Endpoint,
            path: "/"
          }
        ]

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
