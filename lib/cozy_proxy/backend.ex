defmodule CozyProxy.Backend do
  @moduledoc false

  defstruct plug: :unset,
            method: :unset,
            host: :unset,
            path: :unset,
            path_info: :unset

  @type t :: %__MODULE__{}

  @doc false
  def new!(config) do
    config
    |> as_map!()
    |> transform_plug()
    |> transform_path()
    |> as_struct!()
  end

  defp as_map!(config) when is_map(config), do: config
  defp as_map!(config) when is_list(config), do: Enum.into(config, %{})

  defp as_map!(config) do
    raise ArgumentError,
          "backend config should be a map or a keyword list, but #{inspect(config)} is provided"
  end

  defp transform_plug(%{plug: plug} = config) do
    plug =
      case plug do
        {mod, opts} -> {mod, mod.init(opts)}
        mod -> {mod, mod.init([])}
      end

    %{config | plug: plug}
  end

  defp transform_plug(config), do: config

  defp transform_path(%{path: path} = config) do
    path_info = String.split(path, "/", trim: true)
    Map.put(config, :path_info, path_info)
  end

  defp transform_path(config), do: config

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end
end
