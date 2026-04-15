defmodule BeamjsCore.Transpiler do
  @moduledoc """
  Lightweight TypeScript to JavaScript transpiler.
  Phase 1: Strip type annotations using regex-based approach.
  """

  @doc "Strip TypeScript type annotations to produce valid JavaScript."
  def strip_types(source) do
    source
    |> remove_type_imports()
    |> remove_interfaces()
    |> remove_type_aliases()
    |> remove_type_annotations()
    |> remove_return_types()
    |> remove_generics()
    |> remove_as_assertions()
    |> remove_non_null_assertions()
  end

  @doc "Check if a file needs transpilation."
  def needs_transpile?(filename) do
    Path.extname(filename) in [".ts", ".tsx", ".mts"]
  end

  defp remove_type_imports(source) do
    # Remove `import type { ... } from "...";`
    Regex.replace(~r/import\s+type\s+\{[^}]*\}\s+from\s+["'][^"']*["']\s*;?/m, source, "")
  end

  defp remove_interfaces(source) do
    # Remove interface declarations
    Regex.replace(~r/^(?:export\s+)?interface\s+\w+(?:\s+extends\s+\w+)?\s*\{[^}]*\}/ms, source, "")
  end

  defp remove_type_aliases(source) do
    # Remove type aliases
    Regex.replace(~r/^(?:export\s+)?type\s+\w+(?:<[^>]*>)?\s*=[^;]*;/m, source, "")
  end

  defp remove_type_annotations(source) do
    # Remove `: Type` annotations on parameters and variables
    Regex.replace(~r/:\s*(?:readonly\s+)?(?:\w+(?:\[\])?(?:\s*\|\s*\w+(?:\[\])?)*(?:<[^>]*>)?)/m, source, "")
  end

  defp remove_return_types(source) do
    # Remove return type annotations ): Type {
    Regex.replace(~r/\)\s*:\s*(?:\w+(?:<[^>]*>)?(?:\s*\|\s*\w+)*)\s*\{/, source, ") {")
  end

  defp remove_generics(source) do
    # Remove generic type parameters <T, U>
    Regex.replace(~r/<(?:\w+(?:\s+extends\s+\w+)?(?:\s*,\s*\w+(?:\s+extends\s+\w+)?)*)>/, source, "")
  end

  defp remove_as_assertions(source) do
    # Remove `as Type` assertions
    Regex.replace(~r/\s+as\s+\w+(?:<[^>]*>)?/, source, "")
  end

  defp remove_non_null_assertions(source) do
    # Remove non-null assertion operator !. (but not !==)
    Regex.replace(~r/!\./, source, ".")
  end
end
