defmodule Workex.Worker do
  use ExActor.Tolerant

  defstruct [:queue_pid, :callback, :state]

  defstart start(queue_pid, callback, arg)
  defstart start_link(queue_pid, callback, arg)

  definit {queue_pid, callback, arg} do
    case callback.init(arg) do
      {:stop, reason} -> {:stop, reason}
      {:ok, state} ->
        %__MODULE__{
          queue_pid: queue_pid,
          callback: callback,
          state: state
        }
        |> initial_state
    end
  end


  defcast process(messages),
    state: %__MODULE__{queue_pid: queue_pid, callback: callback, state: state} = worker
  do
    case callback.handle(messages, state) do
      {:ok, new_state} ->
        send(queue_pid, {:workex, :worker_available})
        new_state(%__MODULE__{worker | state: new_state})
      {:stop, reason} -> {:stop, reason, state}
    end
  end
end