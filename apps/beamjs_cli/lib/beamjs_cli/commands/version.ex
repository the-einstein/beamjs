defmodule BeamjsCli.Commands.Version do
  def run do
    IO.puts("BeamJS v0.1.0 (QuickJS on BEAM/OTP #{System.otp_release()})")
    IO.puts("Elixir #{System.version()}")
  end
end
