defprotocol Workex.Aggregate do
  def add(data, message)
  def value(data)
  def empty?(data)
end

defmodule Workex.Stack do
  defstruct items: []

  def add(%__MODULE__{items: items} = stack, message) do
    %__MODULE__{stack | items: [message | items]}
  end

  def value(%__MODULE__{items: items}), do: {items, %__MODULE__{}}

  def empty?(%__MODULE__{items: []}), do: true
  def empty?(%__MODULE__{items: _}), do: false

  defimpl Workex.Aggregate do
    defdelegate add(data, message), to: Workex.Stack
    defdelegate value(data), to: Workex.Stack
    defdelegate empty?(data), to: Workex.Stack
  end
end


defmodule Workex.Queue do
  defstruct items: []

  def add(%__MODULE__{items: items} = queue, message) do
    %__MODULE__{queue | items: [message | items]}
  end

  def value(%__MODULE__{items: items}), do: {Enum.reverse(items), %__MODULE__{}}

  def empty?(%__MODULE__{items: []}), do: true
  def empty?(%__MODULE__{items: _}), do: false

  defimpl Workex.Aggregate do
    defdelegate add(data, message), to: Workex.Queue
    defdelegate value(data), to: Workex.Queue
    defdelegate empty?(data), to: Workex.Queue
  end
end


defmodule Workex.Dict do
  defstruct items: HashDict.new

  def add(%__MODULE__{items: items} = queue, {key, value}) do
    %__MODULE__{queue | items: HashDict.put(items, key, value)}
  end

  def value(%__MODULE__{items: items}), do: {HashDict.to_list(items), %__MODULE__{}}

  def empty?(%__MODULE__{items: items}), do: HashDict.size(items) == 0

  defimpl Workex.Aggregate do
    defdelegate add(data, message), to: Workex.Dict
    defdelegate value(data), to: Workex.Dict
    defdelegate empty?(data), to: Workex.Dict
  end
end