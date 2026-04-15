defmodule BeamjsCli.Commands.Test do
  @moduledoc "Run BeamJS tests."

  def run(args, _opts) do
    Application.ensure_all_started(:beamjs_core)

    test_files = case args do
      [] -> find_test_files(".")
      files -> files
    end

    if Enum.empty?(test_files) do
      IO.puts("No test files found.")
      IO.puts("Test files should be in test/ and end with .test.js or .test.ts")
    else
      IO.puts("Running #{length(test_files)} test file(s)...\n")

      results = Enum.map(test_files, fn file ->
        IO.puts("#{file}")
        run_test_file(file)
      end)

      total_passed = Enum.sum(Enum.map(results, & &1.passed))
      total_failed = Enum.sum(Enum.map(results, & &1.failed))

      IO.puts("\n---")
      IO.puts("Total: #{total_passed} passed, #{total_failed} failed")

      if total_failed > 0 do
        System.halt(1)
      end
    end
  end

  defp find_test_files(dir) do
    test_dir = Path.join(dir, "test")
    if File.dir?(test_dir) do
      Path.wildcard(Path.join(test_dir, "**/*.test.{js,ts}"))
    else
      []
    end
  end

  defp run_test_file(file) do
    source = File.read!(file)
    source = if BeamjsCore.Transpiler.needs_transpile?(file) do
      BeamjsCore.Transpiler.strip_types(source)
    else
      source
    end

    case BeamjsCore.Process.eval_sync(source, filename: file) do
      {:ok, %{"passed" => passed, "failed" => failed}} ->
        %{passed: passed || 0, failed: failed || 0}
      {:ok, _} ->
        %{passed: 0, failed: 0}
      {:error, {:js_exception, message, stack}} ->
        IO.puts(:stderr, "  Error in #{file}: #{message}")
        if stack, do: IO.puts(:stderr, "  #{stack}")
        %{passed: 0, failed: 1}
      {:error, reason} ->
        IO.puts(:stderr, "  Error in #{file}: #{inspect(reason)}")
        %{passed: 0, failed: 1}
    end
  end
end
