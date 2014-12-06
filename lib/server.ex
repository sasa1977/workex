defmodule Workex.Server do
  defstruct [:worker_pid, :messages, :behaviour, :worker_available]
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  defstart start(worker_args)
  defstart start_link(worker_args)

  definit {worker_args} do
    behaviour = worker_args[:behaviour] || Workex.Behaviour.Queue
    %__MODULE__{
      behaviour: behaviour,
      messages: behaviour.init
    }
    |> start_worker(Keyword.take(worker_args, [:job, :state]) |> adjust_job(worker_args[:throttle]))
    |> initial_state
  end

  defp adjust_job(worker_args, nil), do: worker_args
  defp adjust_job(worker_args, throttle_time) do
    Keyword.put(worker_args, :job, fn(messages, state) ->
      Workex.Throttler.throttle(throttle_time, fn() -> worker_args[:job].(messages, state) end)
    end)
  end

  defp start_worker(state, worker_args) do
    {:ok, worker_pid} = Workex.Worker.start_link([queue_pid: self] ++ worker_args)
    %__MODULE__{state | worker_pid: worker_pid, worker_available: true}
  end


  defcast push(message),
    state: %__MODULE__{behaviour: behaviour, messages: messages} = state
  do
    %__MODULE__{state | messages: behaviour.add(messages, message)}
    |> maybe_notify_worker
    |> new_state
  end


  defp maybe_notify_worker(%__MODULE__{worker_available: true, worker_pid: worker_pid} = state) do
    unless empty?(state) do
      Workex.Worker.process(worker_pid, transform_messages(state))
      clear_messages(%__MODULE__{state | worker_available: false})
    else
      state
    end
  end

  defp maybe_notify_worker(state), do: state


  defp empty?(%__MODULE__{behaviour: behaviour, messages: messages}) do
    behaviour.empty?(messages)
  end

  defp clear_messages(%__MODULE__{messages: messages, behaviour: behaviour} = state) do
    %__MODULE__{state | messages: behaviour.clear(messages)}
  end

  defp transform_messages(%__MODULE__{behaviour: behaviour, messages: messages}) do
    behaviour.transform(messages)
  end


  defhandleinfo {:workex, :worker_available}, state: state do
    %__MODULE__{state | worker_available: true}
    |> maybe_notify_worker
    |> new_state
  end

  defhandleinfo _, do: noreply
end