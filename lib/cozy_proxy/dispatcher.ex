defmodule CozyProxy.Dispatcher do
  @moduledoc false

  require Logger
  alias CozyProxy.Backend
  alias CozyProxy.ErrorPlug

  @behaviour Plug

  @impl true
  def init(backends: backends) do
    backends =
      Enum.map(backends, fn backend ->
        plug =
          case backend.plug do
            {mod, opts} -> {mod, mod.init(opts)}
            mod -> {mod, mod.init([])}
          end

        %{backend | plug: plug}
      end)

    [backends: backends]
  end

  @impl true
  def call(conn, backends: backends) do
    {conn, backend} = choose_backend(conn, backends)
    dispatch(conn, backend)
  end

  @fallback_backend %Backend{plug: {ErrorPlug, []}}

  defp choose_backend(conn, backends) do
    Enum.find_value(backends, {conn, @fallback_backend}, fn backend ->
      {conn, is_matched?} = match_backend(conn, backend)
      if is_matched?, do: {conn, backend}
    end)
  end

  defp match_backend(conn, %Backend{} = backend) do
    checks = [&check_method/2, &check_host/2, &check_path/2]

    Enum.reduce_while(checks, {conn, true}, fn check, _acc ->
      result = {_conn, is_matched?} = check.(conn, backend)

      action = if is_matched?, do: :halt, else: :cont
      {action, result}
    end)
  end

  defp check_method(conn, %Backend{method: :unset}), do: {conn, false}
  defp check_method(conn, %Backend{method: method}), do: {conn, method == conn.method}

  defp check_host(conn, %Backend{host: :unset}), do: {conn, false}
  defp check_host(conn, %Backend{host: host}), do: {conn, host == conn.host}

  defp check_path(conn, %Backend{path: :unset}), do: {conn, false}

  defp check_path(conn, %Backend{path: path}) do
    conn_path_info = String.split(conn.request_path, "/", trim: true)
    matched_path_info = String.split(path, "/", trim: true)

    if List.starts_with?(conn_path_info, matched_path_info) do
      # Rewrite the request path
      #
      # If there's a backend like this:
      #
      #   %Backend{
      #     plug: ...,
      #     method: nil,
      #     host: nil,
      #     path: "/api"
      #   }
      #
      # The request path "/api/v1/users" will be rewritten as "/v1/users".
      #
      count = length(conn_path_info) - length(matched_path_info)
      new_path_info = Enum.take(conn_path_info, -count)
      {rewrite_path(conn, new_path_info), true}
    else
      {conn, false}
    end
  end

  defp rewrite_path(conn, path_info) do
    request_path =
      path_info
      |> Enum.join("/")
      |> then(&"/#{&1}")

    %{
      conn
      | request_path: request_path,
        path_info: path_info
    }
  end

  defp dispatch(conn, %Backend{plug: plug}) do
    case plug do
      {plug, opts} -> plug.call(conn, opts)
      plug -> plug.call(conn, [])
    end
  end
end
