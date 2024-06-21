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
    [&check_method/2, &check_host/2, &check_path/2]
    |> Enum.reduce_while({conn, true}, fn check, _acc ->
      case check.(conn, backend) do
        {conn, false} -> {:cont, {conn, false}}
        {conn, true} -> {:halt, {conn, true}}
      end
    end)
  end

  defp check_method(conn, %Backend{method: :unset}), do: {conn, false}
  defp check_method(conn, %Backend{method: method}), do: {conn, method == conn.method}

  defp check_host(conn, %Backend{host: :unset}), do: {conn, false}
  defp check_host(conn, %Backend{host: host}) when is_binary(host), do: {conn, host == conn.host}

  defp check_host(conn, %Backend{host: host_regex}) when is_struct(host_regex, Regex) do
    {conn, String.match?(conn.host, host_regex)}
  end

  defp check_path(conn, %Backend{path_info: :unset}), do: {conn, false}

  defp check_path(conn, %Backend{path_info: path_info}),
    do: {conn, List.starts_with?(conn.path_info, path_info)}

  # Inspired by `Plug.forward/4`
  defp dispatch(conn, %Backend{
         plug: {mod, opts},
         path_info: path_info_prefix,
         rewrite_path_info: true
       })
       when is_list(path_info_prefix) do
    %{
      path_info: path_info,
      script_name: script_name
    } = conn

    # rewrite path_info of conn and sent it to the plug module
    conn =
      conn
      |> rewrite_path_info(path_info_prefix)
      |> mod.call(opts)

    # restore path_info of conn
    %{
      conn
      | path_info: path_info,
        script_name: script_name
    }
  end

  defp dispatch(conn, %Backend{plug: {mod, opts}}) do
    mod.call(conn, opts)
  end

  defp rewrite_path_info(conn, path_info_prefix) do
    %{path_info: path_info, script_name: script_name} = conn

    {base, new_path_info} = Enum.split(path_info, length(path_info_prefix))
    new_script_name = script_name ++ base

    %{
      conn
      | path_info: new_path_info,
        script_name: new_script_name
    }
  end
end
