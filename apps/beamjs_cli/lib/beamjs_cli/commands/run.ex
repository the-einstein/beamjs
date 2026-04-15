defmodule BeamjsCli.Commands.Run do
  @moduledoc "Execute a JavaScript/TypeScript file."

  def run([], _opts) do
    IO.puts(:stderr, "Error: no file specified")
    IO.puts(:stderr, "Usage: beamjs run <file>")
    System.halt(1)
  end

  def run([file | _], _opts) do
    Application.ensure_all_started(:beamjs_core)

    file = Path.expand(file)

    unless File.exists?(file) do
      IO.puts(:stderr, "Error: file not found: #{file}")
      System.halt(1)
    end

    source = File.read!(file)

    # Transpile TypeScript if needed
    source = if BeamjsCore.Transpiler.needs_transpile?(file) do
      BeamjsCore.Transpiler.strip_types(source)
    else
      source
    end

    case BeamjsCore.Process.eval_sync(source, filename: file) do
      {:ok, _result} ->
        :ok
      {:error, {:js_exception, message, stack}} ->
        IO.puts(:stderr, "Error: #{message}")
        if stack != "" and stack != nil do
          IO.puts(:stderr, stack)
        end
        System.halt(1)
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
