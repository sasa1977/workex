defprotocol Workex.Aggregate do
  @moduledoc """
  Specifies the protocol used by `Workex` behaviour to aggregate incoming messages.
  """

  @type value :: any

  @doc "Adds the new item to the aggregate."
  @spec add(t, any) :: t
  def add(aggregate, message)

  @doc """
    Produces an aggregated value from all collected items.

    The returned tuple contains aggregated items, and the new instance that doesn't
    contain those items.
  """
  @spec value(t) :: {value, t}
  def value(aggregate)

  @doc """
  Returns the number of aggregated items.

  This function is invoked frequently, so be sure to make the implementation fast.
  """
  @spec size(t) :: non_neg_integer
  def size(aggregate)

  @doc """
  Removes the oldest item from the collection.

  Sometimes it doesn't make sense to implement this function, for example when the
  aggregation doesn't guarantee or preserve ordering. In such cases, just raise from
  the implementation, and document that the implementation can't be used with the
  `replace_oldest` option.
  """
  @spec remove_oldest(t) :: t
  def remove_oldest(aggregate)
end


defmodule Workex.Stack do
  @moduledoc """
  Aggregates messages in the stack like fashion. The aggregated value will contain
  newer messages first.
  """
  defstruct items: :queue.new, size: 0

  @doc false
  def add(%__MODULE__{items: items, size: size} = stack, message) do
    {:ok, %__MODULE__{stack | items: :queue.in_r(message, items), size: size + 1}}
  end

  @doc false
  def value(%__MODULE__{items: items}) do
    {:queue.to_list(items), %__MODULE__{}}
  end

  @doc false
  def size(%__MODULE__{size: size}), do: size

  @doc false
  def remove_oldest(%__MODULE__{items: items, size: size} = stack) do
    {_, items} = :queue.out_r(items)
    %__MODULE__{stack | items: items, size: size - 1}
  end

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Stack
    defdelegate value(aggregate), to: Workex.Stack
    defdelegate size(aggregate), to: Workex.Stack
    defdelegate remove_oldest(aggregate), to: Workex.Stack
  end
end


defmodule Workex.Queue do
  @moduledoc """
  Aggregates messages in the queue like fashion. The aggregated value will be a list
  that preserves the order of messages.
  """
  defstruct items: :queue.new, size: 0

  @doc false
  def add(%__MODULE__{items: items, size: size} = queue, message) do
    {:ok, %__MODULE__{queue | items: :queue.in(message, items), size: size + 1}}
  end

  @doc false
  def value(%__MODULE__{items: items}) do
    {:queue.to_list(items), %__MODULE__{}}
  end

  @doc false
  def size(%__MODULE__{size: size}), do: size

  @doc false
  def remove_oldest(%__MODULE__{items: items, size: size} = queue) do
    {_, items} = :queue.out(items)
    %__MODULE__{queue | items: items, size: size - 1}
  end

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Queue
    defdelegate value(aggregate), to: Workex.Queue
    defdelegate size(aggregate), to: Workex.Queue
    defdelegate remove_oldest(aggregate), to: Workex.Queue
  end
end


defmodule Workex.Dict do
  @moduledoc """
  Assumes that messages are key-value pairs. The new message will overwrite the
  existing one of the same key. The aggregated value is a list of key-value tuples.
  Ordering is not preserved.
  """
  defstruct items: Map.new

  @doc false
  def add(%__MODULE__{items: items} = dict, {key, value}) do
    {:ok, %__MODULE__{dict | items: Map.put(items, key, value)}}
  end

  @doc false
  def value(%__MODULE__{items: items}) do
    {Map.to_list(items), %__MODULE__{}}
  end

  @doc false
  def size(%__MODULE__{items: items}), do: Map.size(items)

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Workex.Dict
    defdelegate value(aggregate), to: Workex.Dict
    defdelegate size(aggregate), to: Workex.Dict
    def remove_oldest(_), do: raise("not implemented")
  end
end
