defmodule SamplePhoenix.Router do
  @moduledoc false

  use Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
  end

  scope "/", SamplePhoenix do
    pipe_through(:browser)

    get "/", Controller, :index

    # Prevent a horrible error because ErrorView is missing
    get "/favicon.ico", Controller, :index
  end
end
