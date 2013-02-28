defmodule Workex.RecordHelper.DynGenerator do
  defmacro __using__(_) do
    generate_macros(function(:def_fields, 1)) ++
    generate_macros(function(:def_this, 1)) ++
    [def_this([])]
  end

  defp generate_macros(generator) do
    Enum.map(1..20, fn(i) ->
      generator.(args(i))
    end)
  end

  defp def_fields(args) do
    quote do 
      defmacro fields(unquote_splicing(args)) do
        define_fields([unquote_splicing(args)])
      end
    end
  end

  defp def_this(args) do
    quote do 
      defmacro this(unquote_splicing(args)) do
        define_this([unquote_splicing(args)])
      end
    end
  end

  defp args(n) do
    Enum.map(1..n, fn(i) -> {binary_to_atom("arg#{i}"), [], nil} end)
  end
end

defmodule Workex.RecordHelper do
  defmacro fields(args) when is_list(args) do
    define_fields(args)
  end

  use Workex.RecordHelper.DynGenerator
  
  defp define_this(args) do
    quote do
      unquote(define_fields(args)) = unquote({:this, [], nil})
    end
  end

  defp define_fields(args) do
    quote do
      __MODULE__[unquote(Enum.map(args, function(:field, 1)))]
    end
  end

  defp field({field, pattern}) do
    quote do
      {unquote(field), unquote(pattern)}
    end
  end

  defp field(name), do: field({elem(name, 0), name})
end