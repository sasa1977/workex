defrecord Workex.Priority, [
    elements: HashDict.new, largest_priority: nil
  ] do
    def empty?(this), do: (Dict.size(this.elements) == 0)

    def add(priority, element, this) when is_number(priority) do
      this.
        add_element(priority, element).
        set_largest_priority(priority)
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

    def set_largest_priority(priority, this) do
      this.update_largest_priority(function do
        (nil) -> priority
        (largest_priority) when largest_priority >= priority -> largest_priority
        _ -> priority
      end)
    end
  end