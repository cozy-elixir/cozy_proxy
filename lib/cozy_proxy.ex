defmodule CozyProxy do
  @moduledoc """

  ## Example

      children = [
        {CozyProxy,
         [
           http: [port: 8080],
           https: [port: 8443],
           backends: [
             %{
               plug: DemoWeb.Endpoint,
               domain: "site1.example.com"
             },
             %{
               plug: {DemoPlug, []},
               domain: "site2.example.com"
             }
           ]
         ]}
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
        [build_child(scheme, options, config.backends) | children]
      else
        children
      end
    end)
  end

  defp build_child(scheme, options, backends) do
    {
      Plug.Cowboy,
      scheme: scheme, plug: {Dispatcher, [backends: backends]}, options: options
    }
  end
end
