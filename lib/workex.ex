defmodule Workex do
  defstruct [:worker_pid, :aggregate, :worker_available, :max_size]
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
    Process.flag(:trap_exit, true)
    case (Workex.Worker.start_link(self, callback, arg)) do
      {:ok, worker_pid} ->
        %__MODULE__{
          aggregate: opts[:aggregate] || %Workex.Stack{},
          worker_pid: worker_pid,
          max_size: opts[:max_size] || :unbound,
          worker_available: true
        }
        |> initial_state
      {:error, reason} -> {:stop, reason}
    end
  end

  def push_ack(server, message, timeout \\ :timer.seconds(5)) do
    GenServer.call(server, {:push_ack, message}, timeout)
  end

  defhandlecall push_ack(message), state: state do
    {response, state} = add_and_notify(state, message)
    set_and_reply(state, response)
  end

  defcast push(message), state: state do
    {_, state} = add_and_notify(state, message)
    new_state(state)
  end

  defp add_and_notify(
    %__MODULE__{aggregate: aggregate, max_size: max_size, worker_available: worker_available} = state,
    message
  ) do
    if (not worker_available) and Aggregate.size(aggregate) == max_size do
      {{:error, :max_capacity}, state}
    else
      case Aggregate.add(aggregate, message) do
        {:ok, new_aggregate} ->
          {:ok,
            %__MODULE__{state | aggregate: new_aggregate}
            |> maybe_notify_worker
          }
        error ->
          {error, state}
      end
    end
  end


  defp maybe_notify_worker(
    %__MODULE__{worker_available: true, worker_pid: worker_pid, aggregate: aggregate} = state
  ) do
    unless Aggregate.size(aggregate) == 0 do
      {payload, aggregate} = Aggregate.value(aggregate)
      Workex.Worker.process(worker_pid, payload)
      %__MODULE__{state | worker_available: false, aggregate: aggregate}
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

  defhandleinfo {:EXIT, worker_pid, reason}, state: %__MODULE__{worker_pid: worker_pid} do
    stop_server(reason)
  end

  defhandleinfo _, do: noreply
end