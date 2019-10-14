defmodule Quetzal.Callback do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: Quetzal.Callback)
  end

  @impl true
  def init([]) do
    {:ok, []}
  end

  @impl true
  def handle_call({:dispatch, _opts, _event, []}, _from, state), do: {:reply, [], state}
  def handle_call({:dispatch, opts, event, params}, _from, state) do
    # get target changed and get its value from params
    [target|_] = params
    |> Map.get("_target")

    # since targets could be wrapped in a form, send all changes
    # in order to allow clients to use cascade updates
    values = params
    |> Map.delete("_target")
    |> Map.values

    # build arguments
    args = [event, target, values]

    # get module and functions to call
    mod = opts[:handler]
    funs = opts[:callbacks]

    output = funs
    |> Enum.map(fn fun ->
         try do
           :erlang.apply(mod, fun, args)
         rescue
           error ->
             Logger.error "Quetzal.Callback Error trying to apply:\n" <>
               "#{inspect mod}:#{inspect fun}(#{inspect args})\n" <>
               "caused by: #{inspect error}"
             {:error, error}
         end
    end)
    |> :lists.append

    {:reply, output, state}
  end
end
