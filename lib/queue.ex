defmodule Workex.Worker.Queue do
  defstruct [:worker_pid, :messages, :behaviour, {:worker_available, true}]

  def new(data) do
    %__MODULE__{
      behaviour: data[:behaviour] || Workex.Behaviour.Queue
    }
    |> init_messages
    |> start_worker(job_args(data))
  end

  def worker_pid(queue, worker_pid) do
    %__MODULE__{queue | worker_pid: worker_pid}
  end

  defp init_messages(
    %__MODULE__{behaviour: behaviour} = queue
  ), do: %__MODULE__{queue | messages: behaviour.init}


  defp job_args(data) do
    Keyword.take(data, [:job, :state])
    |> adjust_job(data[:throttle])
  end

  defp adjust_job(data, nil), do: data
  defp adjust_job(data, throttle_time) do
    Keyword.put(data, :job, fn(messages, state) ->
      Workex.Throttler.throttle(throttle_time, fn() -> data[:job].(messages, state) end)
    end)
  end

  defp start_worker(queue, worker_args) do
    {:ok, worker_pid} = Workex.Worker.start_link([queue_pid: self] ++ worker_args)
    %__MODULE__{queue | worker_pid: worker_pid}
  end

  defp maybe_notify_worker(
    %__MODULE__{worker_available: true, worker_pid: worker_pid} = queue
  ) do
    unless empty?(queue) do
      Workex.Worker.process(worker_pid, transform_messages(queue))

      queue
      |> worker_available(false)
      |> clear_messages
    else
      queue
    end
  end

  defp maybe_notify_worker(queue), do: queue

  def worker_available(queue, value) do
    %__MODULE__{queue | worker_available: value}
    |> maybe_notify_worker
  end

  def push(
    %__MODULE__{behaviour: behaviour, messages: messages} = queue,
    message
  ) do
    %__MODULE__{queue | messages: behaviour.add(messages, message)}
    |> maybe_notify_worker
  end



  defp clear_messages(%__MODULE__{messages: messages, behaviour: behaviour} = queue) do
    %__MODULE__{queue | messages: behaviour.clear(messages)}
  end

  defp transform_messages(%__MODULE__{behaviour: behaviour, messages: messages}) do
    behaviour.transform(messages)
  end

  defp empty?(%__MODULE__{behaviour: behaviour, messages: messages}) do
    behaviour.empty?(messages)
  end
end