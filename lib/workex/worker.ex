defmodule Workex.Worker do
  @moduledoc false
  use ExActor.Tolerant

  defstruct [:queue_pid, :callback, :state]

  defstart start(queue_pid, callback, arg)
  defstart start_link(queue_pid, callback, arg)

  definit {queue_pid, callback, arg} do
    case callback.init(arg) do
      {:ok, state} ->
        %__MODULE__{
          queue_pid: queue_pid,
          callback: callback,
          state: state
        }
        |> initial_state
      other -> other
    end
  end


  defcast process(messages),
    state: %__MODULE__{callback: callback, state: state} = worker_state
  do
    callback.handle(messages, state)
    |> handle_response(worker_state)
  end

  defhandleinfo message,
    state: %__MODULE__{callback: callback, state: state} = worker_state
  do
    callback.handle_message(message, state)
    |> handle_response(worker_state)
  end

  defp handle_response(
    response,
    %__MODULE__{queue_pid: queue_pid, state: state} = worker_state
  ) do
    case response do
      {:ok, new_state} ->
        send(queue_pid, {:workex, :worker_available})
        new_state(%__MODULE__{worker_state | state: new_state})

      {:ok, new_state, timeout_or_hibernate} ->
        send(queue_pid, {:workex, :worker_available})
        new_state(%__MODULE__{worker_state | state: new_state}, timeout_or_hibernate)

      {:stop, reason, new_state} ->
        {:stop, reason, %__MODULE__{worker_state | state: new_state}}

      {:stop, reason} -> {:stop, reason, state}
    end
  end
end