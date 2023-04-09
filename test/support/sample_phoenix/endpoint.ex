defmodule SamplePhoenix.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :sample_phoenix

  plug SamplePhoenix.Router
end
