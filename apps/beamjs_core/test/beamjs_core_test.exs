defmodule BeamjsCoreTest do
  use ExUnit.Case

  test "eval_sync returns integer" do
    assert {:ok, 42} = BeamjsCore.eval_sync("40 + 2")
  end

  test "eval_sync returns string" do
    assert {:ok, "hello"} = BeamjsCore.eval_sync("'hello'")
  end

  test "eval_sync with JS error" do
    assert {:error, _} = BeamjsCore.eval_sync("throw new Error('boom')")
  end

  test "eval_sync console.log" do
    assert {:ok, :undefined} = BeamjsCore.eval_sync("console.log('test')")
  end

  test "eval_sync array" do
    assert {:ok, [2, 4, 6]} =
      BeamjsCore.eval_sync("[1,2,3].map(function(n) { return n * 2; })")
  end

  test "eval_sync object" do
    {:ok, result} = BeamjsCore.eval_sync("({name: 'BeamJS'})")
    assert result["name"] == "BeamJS"
  end

  test "transpiler strips type annotations" do
    ts = "const x: number = 42;"
    js = BeamjsCore.Transpiler.strip_types(ts)
    refute String.contains?(js, ": number")
  end

  test "transpiler needs_transpile?" do
    assert BeamjsCore.Transpiler.needs_transpile?("foo.ts")
    assert BeamjsCore.Transpiler.needs_transpile?("bar.tsx")
    refute BeamjsCore.Transpiler.needs_transpile?("baz.js")
  end
end
