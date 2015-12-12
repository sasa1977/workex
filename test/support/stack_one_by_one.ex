defmodule StackOneByOne do
  defstruct items: []

  def add(%__MODULE__{items: items} = stack, message) do
    {:ok, %__MODULE__{stack | items: [message | items]}}
  end

  def value(%__MODULE__{items: [head | rest]} = stack), do: {head, %__MODULE__{stack | items: rest}}

  def size(%__MODULE__{items: items}), do: length(items)

  defimpl Workex.Aggregate do
    defdelegate add(data, message), to: StackOneByOne
    defdelegate value(data), to: StackOneByOne
    defdelegate size(data), to: StackOneByOne
    def remove_oldest(_), do: raise("not implemented")
  end
end