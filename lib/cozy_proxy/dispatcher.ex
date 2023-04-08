defmodule CozyProxy.Dispatcher do
  @moduledoc false

  require Logger
  alias CozyProxy.Backend
  alias CozyProxy.ErrorPlug

  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, backends: backends) do
    backend = choose_backend(conn, backends)
    dispatch(conn, backend)
  end

  @fallback_backend %Backend{plug: ErrorPlug}

  defp choose_backend(conn, backends) do
    Enum.find(backends, @fallback_backend, fn backend ->
      is_backend_matched?(conn, backend)
    end)
  end

  defp is_backend_matched?(conn, %Backend{verb: verb, domain: domain, host: host, path: path}) do
    is_verb_matched? = if verb, do: Regex.match?(verb, conn.method), else: true
    is_domain_matched? = if domain, do: conn.host == domain, else: true
    is_host_matched? = if host, do: Regex.match?(host, conn.host), else: true
    is_path_matched? = if path, do: Regex.match?(path, conn.request_path), else: true

    is_verb_matched? && is_domain_matched? && is_host_matched? && is_path_matched?
  end

  defp dispatch(conn, %Backend{plug: plug}) do
    case plug do
      {plug, opts} -> plug.call(conn, opts)
      plug -> plug.call(conn, [])
    end
  end
end
