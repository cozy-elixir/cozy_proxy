defmodule CozyProxy.Backend do
  @moduledoc false

  defstruct plug: :unset,
            method: :unset,
            host: :unset,
            path: :unset

  @type t :: %__MODULE__{}

  @doc false
  def new!(config) do
    config
    |> as_map!()
    |> as_struct!()
    |> validate_plug_option!()
  end

  defp as_map!(config) when is_map(config), do: config
  defp as_map!(config) when is_list(config), do: Enum.into(config, %{})

  defp as_map!(config) do
    raise ArgumentError,
          "backend config should be a map or a keyword list, but #{inspect(config)} is provided"
  end

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end

  defp validate_plug_option!(%__MODULE__{plug: :unset}) do
    raise ArgumentError, "backend must include :plug option"
  end

  defp validate_plug_option!(%__MODULE__{} = config) do
    config
  end
end
