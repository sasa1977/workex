defmodule Workex do
  defstruct [:worker_pid, :messages, :worker_available]
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  use Behaviour

  @type arg :: any
  @type worker_state :: any
  @type message :: any

  defcallback init(arg) :: worker_state
  defcallback handle(any, worker_state) :: worker_state

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  alias Workex.Aggregate

  defstart start(callback, arg, opts \\ []), gen_server_opts: :runtime
  defstart start_link(callback, arg, opts \\ []), gen_server_opts: :runtime

  definit {callback, arg, opts} do
    %__MODULE__{messages: opts[:aggregate] || %Workex.Stack{}}
    |> start_worker(callback, arg)
    |> initial_state
  end

  defp start_worker(state, callback, arg) do
    {:ok, worker_pid} = Workex.Worker.start_link(self, callback, arg)
    %__MODULE__{state | worker_pid: worker_pid, worker_available: true}
  end


  defcast push(message),
    state: %__MODULE__{messages: messages} = state
  do
    %__MODULE__{state | messages: Aggregate.add(messages, message)}
    |> maybe_notify_worker
    |> new_state
  end


  defp maybe_notify_worker(
    %__MODULE__{worker_available: true, worker_pid: worker_pid, messages: messages} = state
  ) do
    unless Aggregate.empty?(messages) do
      {payload, messages} = Aggregate.value(messages)
      Workex.Worker.process(worker_pid, payload)
      %__MODULE__{state | worker_available: false, messages: messages}
    else
      state
    end
  end

  defp maybe_notify_worker(state), do: state


  defhandleinfo {:workex, :worker_available}, state: state do
    %__MODULE__{state | worker_available: true}
    |> maybe_notify_worker
    |> new_state
  end

  defhandleinfo _, do: noreply
end