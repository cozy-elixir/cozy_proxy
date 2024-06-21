defmodule CozyProxy do
  @moduledoc """
  Proxy requests to other plugs.

  ## Usage

  A `CozyProxy` instance is an isolated supervision tree and you can include it in
  application's supervisor:

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
        server: true,
        adapter: Plug.Cowboy,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
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

  When using `CozyProxy` with Phoenix endpoints, it's required to configure
  the path of endpoints to a proper value. And it's better to configure
  `:server` option of endpoints to `false`, which avoids them serving requests
  bypassing `CozyProxy`. For example:

      config :demo, DemoWeb.Endpoint,
        url: [path: "/"],
        server: false

      config :demo, DemoWebAPI.Endpoint,
        url: [path: "/api"],
        server: false

      config :demo, DemoAdminWeb.Endpoint,
        url: [path: "/admin"],
        server: false

  ## Options

    * `:server` - start the web server or not. Default to `false`. It is aware
      of Phoenix startup arguments, if the application is started with
      `mix phx.server` or `iex -S mix phx.server`, this option will set
      to `true`.
    * `:backends` - the list of backends. Default to `[]`. See following section for
      more details.
    * `:adapter` - the adapter for web server, `Plug.Cowboy` and `Bandit` are
      available. Default to `Plug.Cowboy`.
    * adapter options - all other options will be put into an keyword list and
      passed as the options of the adapter. See following section for more details.

  ## About `:backends`

  A valid `:backends` option is a list of maps, and the keys of maps are:

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
      * typespec: `String.t()` | `Regex.t()`
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
    * `:rewrite_path_info`:
      * optional
      * typespec: `boolean()`
      * default: `true`
      * examples:
        * `true`
        * `false`

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
            path: "/health"
          }
        ]

  The first backend will always match, which may not what you expected.

  If you want all backends to have a chance to match, you should configure them like this:

      config :demo, CozyProxy,
        backends: [
          %{
            plug: HealthCheck,
            path: "/health"
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

  ## About adapter options

  In the section of Options, we said:

  > all other options will be put into an keyword list and passed as the options of the adapter.

  It means the all options except `:server`, `:backends`, `:adapter` will be passed as the
  the options of an adapter.

  Take `Plug.Cowboy` adapter as an example. If we declare the options like:

      config :demo, CozyProxy,
        backends: [
          # ...
        ],
        adapter: Plug.Cowboy,
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        transport_options: [num_acceptors: 2]

  Then following options will be passed to `Plug.Cowboy` when initializing CozyProxy:

      [
        scheme: :http,
        ip: {127, 0, 0, 1},
        port: 4000,
        transport_options: [num_acceptors: 2]
      ]

  For more available adapter options:

    * `Plug.Cowboy` - checkout [Plug.Cowboy options](https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html#module-options).
    * `Bandit` - checkout [Bandit options](https://hexdocs.pm/bandit/Bandit.html#t:options/0).

  """

  use Supervisor
  require Logger
  alias CozyProxy.Config
  alias CozyProxy.Dispatcher

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg)
  end

  @impl true
  def init(init_arg) do
    {server, rest_arg} = Keyword.pop(init_arg, :server, false)
    {adapter, rest_arg} = Keyword.pop(rest_arg, :adapter, Plug.Cowboy)
    {backends, rest_arg} = Keyword.pop(rest_arg, :backends, [])

    adapter_config =
      rest_arg
      |> Keyword.delete(:plug)
      |> Keyword.put_new(:scheme, :http)
      |> Keyword.put_new(:ip, {127, 0, 0, 1})
      |> put_new_port()

    config =
      Config.new!(%{
        server: server,
        adapter: adapter,
        adapter_config: adapter_config,
        backends: backends
      })

    check_adapter_module!(config.adapter)

    start_server? = config.server || is_phoenix_on?()

    children =
      if start_server?,
        do: [build_child(config)],
        else: []

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp put_new_port(adapter_config) do
    Keyword.put_new_lazy(adapter_config, :port, fn ->
      scheme = Keyword.fetch!(adapter_config, :scheme)
      get_default_port(scheme)
    end)
  end

  # Same as the default ports of Plug.Cowboy and Bandit
  defp get_default_port(:http = _scheme), do: 4000
  defp get_default_port(:https = _scheme), do: 4040

  defp check_adapter_module!(Plug.Cowboy) do
    unless Code.ensure_loaded?(Plug.Cowboy) do
      Logger.error("""
      Could not find Plug.Cowboy dependency. Please add :plug_cowboy to your dependencies:

          {:plug_cowboy, "~> 2.6"}

      """)

      raise "missing Plug.Cowboy dependency"
    end

    :ok
  end

  defp check_adapter_module!(Bandit) do
    unless Code.ensure_loaded?(Bandit) do
      Logger.error("""
      Could not find Bandit dependency. Please add :bandit to your dependencies:

          {:bandit, "~> 1.0"}

      """)

      raise "missing Bandit dependency"
    end

    :ok
  end

  defp check_adapter_module!(adapter) do
    raise "unknown adapter #{inspect(adapter)}"
  end

  # Consinder Phoenix is on when meets following cases:
  #
  # + run `iex -S mix phx.server`
  # + run `mix phx.server`
  #
  defp is_phoenix_on?() do
    Application.get_env(:phoenix, :serve_endpoints, false)
  end

  defp build_child(%Config{} = config) do
    %{adapter: adapter, adapter_config: adapter_config, backends: backends} = config

    Logger.info(fn -> gen_listen_line(adapter_config) end)

    {
      adapter,
      [plug: {Dispatcher, [backends: backends]}] ++ build_adapter_opts(adapter, adapter_config)
    }
  end

  defp build_adapter_opts(Plug.Cowboy = _adapter, adapter_config) do
    {scheme, options} = Keyword.pop!(adapter_config, :scheme)
    [scheme: scheme, options: options]
  end

  defp build_adapter_opts(Bandit = _adapter, adapter_config) do
    adapter_config
  end

  defp gen_listen_line(adapter_config) do
    scheme = Keyword.fetch!(adapter_config, :scheme)
    ip = Keyword.fetch!(adapter_config, :ip)
    port = Keyword.fetch!(adapter_config, :port)
    "#{inspect(__MODULE__)} is listening on #{scheme}://#{format_ip(ip)}:#{port}"
  end

  defp format_ip(ip) do
    if is_tuple(ip) do
      :inet.ntoa(ip)
    else
      inspect(ip)
    end
  end
end
