defmodule Workex.RecordHelper do
  defmacro fields(args) do
    define_fields(args)
  end
  
  defmacro this(args) do
    define_this(args)
  end
  
  defp define_this(args) do
    quote do
      unquote(define_fields(args)) = unquote({:this, [], nil})
    end
  end

  defp define_fields(args) do
    quote do
      __MODULE__[unquote(Enum.map(args, &field/1))]
    end
  end

  defp field({field, pattern}) do
    quote do
      {unquote(field), unquote(pattern)}
    end
  end

  defp field(name), do: field({elem(name, 0), name})
end