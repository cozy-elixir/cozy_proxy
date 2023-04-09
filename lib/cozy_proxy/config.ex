defmodule CozyProxy.Config do
  @moduledoc false

  alias CozyProxy.Backend

  defstruct http: nil, https: nil, server: false, backends: []

  @type t :: %__MODULE__{}

  @doc false
  def new!(config) do
    config
    |> as_map!()
    |> as_struct!()
    |> validate_backends!()
    |> struct_backends!()
  end

  defp as_map!(config) when is_map(config), do: config
  defp as_map!(config) when is_list(config), do: Enum.into(config, %{})

  defp as_map!(config) do
    raise ArgumentError,
          "config should be a map or a keyword list, but #{inspect(config)} is provided"
  end

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end

  defp validate_backends!(%__MODULE__{backends: backends} = config) when is_list(backends) do
    config
  end

  defp validate_backends!(%__MODULE__{}) do
    raise ArgumentError, "backends config should be a list"
  end

  defp struct_backends!(%__MODULE__{backends: backends} = config) do
    backends = Enum.map(backends, &Backend.new!(&1))
    %{config | backends: backends}
  end
end
