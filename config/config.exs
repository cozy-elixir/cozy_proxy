import Config

if config_env() == :test do
  Application.put_env(:sample_phoenix, SamplePhoenix.Endpoint,
    http: [ip: {127, 0, 0, 1}, port: 5001],
    server: true,
    secret_key_base: String.duplicate("x", 64)
  )
end
