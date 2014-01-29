defmodule Workex.Priority do
  defrecordp :priority_rec, elements: HashDict.new

  def new, do: priority_rec

  def empty?(priority_rec(elements: elements)), do: (Dict.size(elements) == 0)

  def add(
    priority_rec(elements: elements) = priority_rec, 
    priority, 
    element
  ) when is_number(priority) do
    priority_rec(
      priority_rec,
      elements: Dict.put(elements, priority, [element | (elements[priority] || [])])
    )
  end

  def to_list(priority_rec(elements: elements)) do
    Enum.sort(elements.keys)
    |> Enum.reduce([], &(Enum.reverse(elements[&1]) ++ &2))
  end
end