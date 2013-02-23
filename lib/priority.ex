defrecord Workex.Priority, [elements: HashDict.new] do
  def empty?(this), do: (Dict.size(this.elements) == 0)

  def add(priority, element, this) when is_number(priority) do
    this.
      add_element(priority, element)
  end

  def to_list(this) do
    List.foldl(Enum.sort(this.elements.keys), [], fn(priority, acc) ->
      this.add_priorities(priority, acc)
    end)
  end

  def add_priorities(priority, acc, this) do
    List.foldl(this.elements[priority], acc, fn(element, acc) ->
      [element | acc]
    end)
  end

  def add_element(priority, element, this) do
    this.update_elements(fn(elements) ->
      new_array = [element | (this.elements[priority] || [])]
      Dict.put(elements, priority, new_array)
    end)
  end
end