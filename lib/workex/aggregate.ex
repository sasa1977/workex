defprotocol Workex.Aggregate do
  def add(aggregate, message)
  def value(aggregate)
  def size(aggregate)
end

defmodule Workex.Stack do
  defstruct items: [], size: 0

  def add(%__MODULE__{items: items, size: size} = stack, message) do
    {:ok, %__MODULE__{stack | items: [message | items], size: size + 1}}
  end

  def value(%__MODULE__{items: items}) do
    {items, %__MODULE__{}}
  end

  def size(%__MODULE__{size: size}), do: size

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Stack
    defdelegate value(aggregate), to: Workex.Stack
    defdelegate size(aggregate), to: Workex.Stack
  end
end


defmodule Workex.Queue do
  defstruct items: [], size: 0

  def add(%__MODULE__{items: items, size: size} = queue, message) do
    {:ok, %__MODULE__{queue | items: [message | items], size: size + 1}}
  end

  def value(%__MODULE__{items: items}) do
    {Enum.reverse(items), %__MODULE__{}}
  end

  def size(%__MODULE__{size: size}), do: size

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Queue
    defdelegate value(aggregate), to: Workex.Queue
    defdelegate size(aggregate), to: Workex.Queue
  end
end


defmodule Workex.Dict do
  defstruct items: HashDict.new

  def add(%__MODULE__{items: items} = dict, {key, value}) do
    {:ok, %__MODULE__{dict | items: HashDict.put(items, key, value)}}
  end

  def value(%__MODULE__{items: items}) do
    {HashDict.to_list(items), %__MODULE__{}}
  end

  def size(%__MODULE__{items: items}), do: HashDict.size(items)

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Dict
    defdelegate value(aggregate), to: Workex.Dict
    defdelegate size(aggregate), to: Workex.Dict
  end
end