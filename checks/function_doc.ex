defmodule Polymarket.Checks.FunctionDoc do
  use Credo.Check,
    base_priority: :low,
    category: :readability,
    explanations: [
      check: """
      Public functions and macros should carry a `@doc` string.

      Documentation makes a module's public API easier to discover and use. This
      check flags every public `def`/`defmacro` that is not preceded by a `@doc`
      attribute.

          @doc "Adds two integers."
          def add(a, b), do: a + b

      For multi-clause functions only the first clause needs a `@doc`:

          @doc "..."
          def handle(:a), do: ...
          def handle(:b), do: ...

      Functions you deliberately want to leave undocumented can opt out with
      `@doc false`, and behaviour callbacks annotated with `@impl` are skipped
      automatically.

      Like all `Readability` issues, this one is not a technical concern, but it
      makes your code easier for others to follow.
      """
    ]

  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Test/script files (`.exs`) are full of helper defs that don't need docs.
    if Path.extname(filename) == ".exs" do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp traverse({:defmodule, _meta, _args} = ast, issues, issue_meta) do
    statements = Credo.Code.Block.calls_in_do_block(ast)
    {ast, issues ++ scan(statements, issue_meta)}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Walk a module body in source order. `@doc`/`@impl` "arm" an exemption for the
  # next definition; `seen` tracks already-reported `{name, arity}` pairs so only
  # the first clause of a multi-clause function is flagged.
  defp scan(statements, issue_meta) do
    {issues, _armed, _seen} =
      Enum.reduce(statements, {[], false, MapSet.new()}, &scan_statement(&1, &2, issue_meta))

    Enum.reverse(issues)
  end

  defp scan_statement(statement, {issues, armed, seen}, issue_meta) do
    cond do
      exempting_attr?(statement) ->
        {issues, true, seen}

      public_def = public_def(statement) ->
        {name, arity, line} = public_def
        key = {name, arity}

        cond do
          MapSet.member?(seen, key) -> {issues, false, seen}
          armed -> {issues, false, MapSet.put(seen, key)}
          true -> {[issue_for(issue_meta, line, name, arity) | issues], false, MapSet.put(seen, key)}
        end

      # A private def (or other definition) consumes any pending `@doc`/`@impl`.
      definition?(statement) ->
        {issues, false, seen}

      true ->
        {issues, armed, seen}
    end
  end

  # `@doc "..."`, `@doc false`, or `@doc since: "..."` all opt the next def out.
  defp exempting_attr?({:@, _, [{:doc, _, _}]}), do: true
  # `@impl true`/`@impl SomeBehaviour` mark a callback, which we don't require docs for.
  defp exempting_attr?({:@, _, [{:impl, _, [value]}]}), do: value != false
  defp exempting_attr?(_), do: false

  defp public_def({keyword, meta, [head | _]}) when keyword in [:def, :defmacro] do
    case name_and_arity(head) do
      {name, arity} -> {name, arity, meta[:line]}
      :error -> nil
    end
  end

  defp public_def(_), do: nil

  defp definition?({keyword, _, _}) when keyword in [:def, :defp, :defmacro, :defmacrop], do: true
  defp definition?(_), do: false

  defp name_and_arity({:when, _, [head | _]}), do: name_and_arity(head)
  defp name_and_arity({name, _, args}) when is_atom(name), do: {name, arity(args)}
  defp name_and_arity(_), do: :error

  defp arity(args) when is_list(args), do: length(args)
  defp arity(_), do: 0

  defp issue_for(issue_meta, line, name, arity) do
    format_issue(
      issue_meta,
      message: "Public functions should have a @doc string.",
      trigger: "#{name}/#{arity}",
      line_no: line
    )
  end
end
