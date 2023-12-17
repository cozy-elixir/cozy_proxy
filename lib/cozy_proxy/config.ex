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
          "config must be a map or a keyword list, but #{inspect(config)} is given"
  end

  defp as_struct!(config) do
    default_struct = __MODULE__.__struct__()
    valid_keys = Map.keys(default_struct)
    config = Map.take(config, valid_keys)
    Map.merge(default_struct, config)
  end

  defp validate_backends!(%__MODULE__{backends: backends} = config) do
    if !is_list(backends) do
      raise ArgumentError, "backends config must be a list, but #{inspect(backends)} is given"
    end

    for backend <- backends do
      if !is_map(backend) and !is_list(backend) do
        raise ArgumentError,
              "backend config must be a map or a keyword list, but #{inspect(backend)} is given"
      end

      if !backend.plug do
        raise ArgumentError,
              "backend must include :plug option, but #{inspect(backend)} is given"
      end
    end

    config
  end

  defp struct_backends!(%__MODULE__{backends: backends} = config) do
    backends = Enum.map(backends, &Backend.new!(&1))
    %{config | backends: backends}
  end
end
