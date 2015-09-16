defmodule Workex do
  @moduledoc """
    A behaviour which separates message receiving and aggregating from message processing.

    Example:

      defmodule Consumer do
        use Workex

        # Interface functions are invoked inside client processes

        def start_link do
          Workex.start_link(__MODULE__, nil)
        end

        def push(pid, item) do
          Workex.push(pid, item)
        end


        # Callback functions run in the worker process

        def init(_), do: {:ok, nil}

        def handle(data, state) do
          Processor.long_op(data)
          {:ok, state}
        end
      end

  The `callback` module must export following functions:

  - init/1 - receives `arg` and should return `{:ok, initial_state}` or `{:stop, reason}`.
  - handle/2 - receives aggregated messages and the state, and should return `{:ok, new_state}`
    or `{:stop, reason}`.
  - handle_message/2 - optional message handler

  The `Workex` starts two processes. The one returned by `Workex.start_link/4` is the "facade"
  process which can be used as the target for messages. This is also the process which aggregates
  messages.

  Callback functions will run in the worker process, which is started by the "main" process.
  Thus, consuming is done concurrently to message aggregation.

  Both processes are linked, and the main process traps exits. Termination of the worker process
  will cause the main process to terminate with the same exit reason.
  """

  defstruct [
    :worker_pid,
    :aggregate,
    :worker_available,
    :max_size,
    :replace_oldest,
    pending_responses: HashSet.new,
    processing_responses: HashSet.new
  ]

  use ExActor.Tolerant

  use Behaviour

  @typep worker_state :: any
  @type workex_options ::
    [{:aggregate, Workex.Aggregate.t} |
    {:max_size, pos_integer} |
    {:replace_oldest, boolean}]
  @typep handle_response ::
  {:ok, worker_state} |
  {:ok, worker_state, pos_integer | :hibernate} |
  {:stop, reason :: any} |
  {:stop, reason :: any, worker_state}

  defcallback init(any) :: {:ok, worker_state} | {:ok, worker_state, pos_integer | :hibernate} | {:stop, reason :: any}
  defcallback handle(Workex.Aggregate.value, worker_state) :: handle_response
  defcallback handle_message(any, worker_state) :: handle_response

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def handle_message(_, state), do: {:ok, state}
      defoverridable handle_message: 2
    end
  end

  alias Workex.Aggregate

  @doc """
  Starts aggregator and worker processes.

  See `start_link/4` for detailed description.
  """
  @spec start(module, any, workex_options, GenServer.options) :: GenServer.on_start
  defstart start(callback, arg, opts \\ []), gen_server_opts: :runtime

  @doc """
  Starts aggregator and worker processes.

  Possible options are:

  - `aggregate` - Aggregation instance. Defaults to `%Workex.Queue{}`. Must implement `Workex.Aggregated`.
  - `max_size` - Maximum number of messages in the buffer after which new messages are discarded.
  - `replace_oldest` - Alters behavior of `max_size`. When the buffer is full, new message replaces the
    oldest one.
  """
  @spec start_link(module, any, workex_options, GenServer.options) :: GenServer.on_start
  defstart start_link(callback, arg, opts \\ []), gen_server_opts: :runtime

  definit {callback, arg, opts} do
    Process.flag(:trap_exit, true)
    case (Workex.Worker.start_link(self, callback, arg)) do
      {:ok, worker_pid} ->
        %__MODULE__{
          aggregate: opts[:aggregate] || %Workex.Queue{},
          worker_pid: worker_pid,
          max_size: opts[:max_size] || :unbound,
          replace_oldest: opts[:replace_oldest] || false,
          worker_available: true
        }
        |> initial_state
      {:error, reason} -> {:stop, reason}
    end
  end

  @doc """
  Pushes a new message, returns immediately.
  """
  @spec push(GenServer.server, any) :: :ok
  defcast push(message), state: state do
    {_, state} = add_and_notify(state, message)
    new_state(state)
  end


  @doc """
  Pushes a new message and returns as soon as the message is queued (or rejected).
  """
  @spec push_ack(GenServer.server, any, non_neg_integer | :infinity) :: :ok | {:error, reason :: any}
  defcall push_ack(message), timeout: timeout \\ 5000, state: state do
    {response, state} = add_and_notify(state, message)
    set_and_reply(state, response)
  end


  @doc """
  Pushes a new message and returns after the message is processed (or rejected).
  """
  @spec push_block(GenServer.server, any, non_neg_integer | :infinity) :: :ok | {:error, reason :: any}
  defcall push_block(message), timeout: timeout \\ 5000, state: state, from: from do
    {response, state} = add_and_notify(state, message, from)
    case response do
      :ok -> new_state(state)
      _ -> set_and_reply(state, response)
    end
  end

  defp add_and_notify(
    %__MODULE__{
      aggregate: aggregate,
      max_size: max_size,
      worker_available: worker_available,
      replace_oldest: replace_oldest
    } = state,
    message,
    from \\ nil
  ) do
    if (not worker_available) and Aggregate.size(aggregate) == max_size do
      if replace_oldest do
        aggregate
        |> Aggregate.remove_oldest
        |> Aggregate.add(message)
        |> handle_add(state, from)
      else
        {{:error, :max_capacity}, state}
      end
    else
      aggregate
      |> Aggregate.add(message)
      |> handle_add(state, from)
    end
  end

  defp handle_add(add_result, state, from) do
    case add_result do
      {:ok, new_aggregate} ->
        {:ok,
          %__MODULE__{state | aggregate: new_aggregate}
          |> add_pending_response(from)
          |> maybe_notify_worker
        }
      error ->
        {error, state}
    end
  end

  defp add_pending_response(state, nil), do: state
  defp add_pending_response(%__MODULE__{pending_responses: pending_responses} = state, from) do
    %__MODULE__{state | pending_responses: HashSet.put(pending_responses, from)}
  end


  defp maybe_notify_worker(
    %__MODULE__{
      worker_available: true,
      worker_pid: worker_pid,
      aggregate: aggregate,
      pending_responses: pending_responses
    } = state
  ) do
    unless Aggregate.size(aggregate) == 0 do
      {payload, aggregate} = Aggregate.value(aggregate)
      Workex.Worker.process(worker_pid, payload)
      %__MODULE__{state |
        worker_available: false,
        aggregate: aggregate,
        processing_responses: pending_responses,
        pending_responses: HashSet.new
      }
    else
      state
    end
  end

  defp maybe_notify_worker(state), do: state


  defhandleinfo {:workex, :worker_available}, state: state do
    %__MODULE__{state | worker_available: true}
    |> notify_pending
    |> maybe_notify_worker
    |> new_state
  end

  defp notify_pending(%__MODULE__{processing_responses: processing_responses} = state) do
    Enum.each(processing_responses, &GenServer.reply(&1, :ok))
    %__MODULE__{state | processing_responses: HashSet.new}
  end


  defhandleinfo {:EXIT, worker_pid, reason}, state: %__MODULE__{worker_pid: worker_pid} do
    stop_server(reason)
  end

  defhandleinfo _, do: noreply
end