defmodule Workex.RecordHelper do
  defmacro fields(args) when is_list(args) do
    define_fields(args)
  end

  defmacro fields(arg), do: define_fields([arg])

  defmacro fields(arg1, arg2), do: define_fields([arg1, arg2])
  defmacro fields(arg1, arg2, arg3), do: define_fields([arg1, arg2, arg3])
  defmacro fields(arg1, arg2, arg3, arg4), do: define_fields([arg1, arg2, arg3, arg4])
  defmacro fields(arg1, arg2, arg3, arg4, arg5), do: define_fields([arg1, arg2, arg3, arg4, arg5])

  defmacro this(), do: define_this([])
  defmacro this(arg1), do: define_this([arg1])
  defmacro this(arg1, arg2), do: define_this([arg1, arg2])
  defmacro this(arg1, arg2, arg3), do: define_this([arg1, arg2, arg3])
  defmacro this(arg1, arg2, arg3, arg4), do: define_this([arg1, arg2, arg3, arg4])
  defmacro this(arg1, arg2, arg3, arg4, arg5), do: define_this([arg1, arg2, arg3, arg4, arg5])

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