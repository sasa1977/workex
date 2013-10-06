defrecord Workex.Priority, [elements: HashDict.new] do
  import Workex.RecordHelper

  def empty?(fields([elements])), do: (Dict.size(elements) == 0)

  def add(priority, element, this([elements])) when is_number(priority) do
    Dict.put(elements, priority, [element | (elements[priority] || [])]) |>
    elements(this)
  end

  def to_list(fields([elements])) do
    List.foldl(Enum.sort(elements.keys), [], fn(priority, acc) ->
      List.foldl(elements[priority], acc, &([&1 | &2]))
    end)
  end
end