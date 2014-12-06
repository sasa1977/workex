defmodule Workex do
  defstruct [:worker_pid, :messages, :callback, :worker_available]
  @moduledoc """
    A gen_server based process which can be used to manipulate multiple workers and send
    them messages. See readme for detailed description.
  """

  use ExActor.Tolerant

  defstart start(callback \\ Workex.Callback.Stack, worker_args), gen_server_opts: :runtime
  defstart start_link(callback \\ Workex.Callback.Stack, worker_args), gen_server_opts: :runtime

  definit {callback, worker_args} do
    %__MODULE__{
      callback: callback,
      messages: callback.init
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
    state: %__MODULE__{callback: callback, messages: messages} = state
  do
    %__MODULE__{state | messages: callback.add(messages, message)}
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


  defp empty?(%__MODULE__{callback: callback, messages: messages}) do
    callback.empty?(messages)
  end

  defp clear_messages(%__MODULE__{messages: messages, callback: callback} = state) do
    %__MODULE__{state | messages: callback.clear(messages)}
  end

  defp transform_messages(%__MODULE__{callback: callback, messages: messages}) do
    callback.transform(messages)
  end


  defhandleinfo {:workex, :worker_available}, state: state do
    %__MODULE__{state | worker_available: true}
    |> maybe_notify_worker
    |> new_state
  end

  defhandleinfo _, do: noreply
end