defrecord Workex.Priority, [elements: HashDict.new] do
  def empty?(__MODULE__[elements: elements]), do: (Dict.size(elements) == 0)

  def add(priority, element, __MODULE__[] = this) when is_number(priority) do
    Dict.put(this.elements, priority, [element | (this.elements[priority] || [])]) 
    |> this.elements
  end

  def to_list(__MODULE__[elements: elements]) do
    List.foldl(Enum.sort(elements.keys), [], fn(priority, acc) ->
      List.foldl(elements[priority], acc, &([&1 | &2]))
    end)
  end
end