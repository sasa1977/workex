defmodule Workex.Behaviour do
  defmodule Spec do
    use Behaviour
    @type message :: any
    @type messages :: any

    defcallback init() :: messages
    defcallback clear(messages) :: messages
    defcallback add(messages, message) :: messages
    defcallback transform(messages) :: messages
    defcallback empty?(messages) :: boolean
  end

  defmodule Base do
    defmacro __using__(_) do
      quote do
        @behaviour Workex.Behaviour.Spec

        def init, do: []
        def clear(_), do: init
        def add(messages, message), do: [message | messages]
        def transform(messages), do: messages
  
        def empty?([]), do: true
        def empty?(_), do: false
    
        defoverridable [init: 0, clear: 1, add: 2, transform: 1, empty?: 1]
      end
    end
  end
  
  defmodule Stack do
    use Workex.Behaviour.Base
  end

  defmodule Queue do
    use Workex.Behaviour.Base
    
    def transform(messages), do: Enum.reverse(messages)
  end

  defmodule Unique do
    use Workex.Behaviour.Base
    
    def init, do: HashDict.new
    def add(messages, message), do: Dict.put(messages, elem(message, 0), message)
    def transform(messages), do: Dict.values(messages)
    def empty?(messages), do: Dict.size(messages) == 0
  end

  defmodule Priority do
    use Workex.Behaviour.Base

    def init, do: Workex.Priority.new
    def add(priority, message), do: Workex.Priority.add(elem(message, 0), message, priority)
    def transform(priority), do: Workex.Priority.to_list(priority)
    def empty?(priority), do: Workex.Priority.empty?(priority)
  end
end