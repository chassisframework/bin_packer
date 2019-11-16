defmodule BinPacker.Constraint do
  alias BinPacker, as: BinPacker
  alias BinPacker.Ball

  @type bin_id :: BinPacker.bin_id
  @type args :: any

  @type state :: any
  @type num_propositions :: pos_integer
  @type proposition :: BinPacker.proposition()
  @type proposition_type :: BinPacker.proposition_type()
  @type propositions :: BinPacker.propositions()

  @type stream :: fun()


  @callback init(args) :: state
  # @callback validate_init_args(args) :: :ok | {:error, any}
  @callback ball_added(BinPacker.t(), Ball.t, state) :: state
  @callback bin_added(BinPacker.t(), Bin.t, state) :: state
  @callback proposition_executed(BinPacker.t(), proposition, state) :: state
  @callback generate_propositions(BinPacker.t(), proposition_type, Ball.t(), state) :: stream
  @callback propose_new_placements(BinPacker.t(), Ball.t(), state) :: stream
  @callback valid_new_placement?(BinPacker.t(), Ball.t(), bin_id, state) :: boolean
  @callback valid_proposition?(BinPacker.t(), proposition, state) :: boolean

  #
  # each constraint generates a list of propositions, then the other constraints reject those that they
  # deem to be invalid. the resulting lists are unioned and deduplicated.
  #
  # this could probably be parallelized (both in generation and rejection), so long as it's still worth
  # it with the Task overhead
  #
  def generate_propositions(%BinPacker{constraints: constraints} = bin_packer, type, ball_id, num) do
    constraints
    |> each_and_others()
    |> Enum.flat_map(fn {{{constraint, _init_args}, state}, others} ->
      bin_packer
      |> constraint.generate_propositions(type, ball_id, state)
      |> Stream.take(num)
      |> Enum.filter(&valid_proposition?(bin_packer, &1, others))
    end)
    |> Enum.uniq()
  end

  def valid_new_placement?(constraints, bin_packer, ball, bin_id) do
    Enum.all?(constraints, fn {constraint, state} ->
      constraint.valid_new_placement?(bin_packer, ball, bin_id, state)
    end)
  end

  def valid_proposition?(%BinPacker{constraints: constraints} = bin_packer, proposition) do
    valid_proposition?(bin_packer, proposition, constraints)
  end

  def valid_proposition?(bin_packer, proposition, constraints) do
    Enum.all?(constraints, fn {{module, _init_args}, state} ->
      module.valid_proposition?(bin_packer, proposition, state)
    end)
  end

  #
  # Notifications
  #
  def ball_added(bin_packer, ball) do
    apply_to_all(bin_packer, :ball_added, [ball])
  end

  def bin_added(bin_packer, bin) do
    apply_to_all(bin_packer, :bin_added, [bin])
  end

  def proposition_executed(bin_packer, proposition) do
    apply_to_all(bin_packer, :proposition_executed, [proposition])
  end


  defp each_and_others(constraints) do
    do_each_and_others([], constraints, [])
  end

  defp do_each_and_others(prev, [constraint | rest], collection) do
    do_each_and_others([constraint | prev], rest, [{constraint, prev ++ rest} | collection])
  end
  defp do_each_and_others(_prev, [], collection), do: collection

  defp apply_to_all(%BinPacker{constraints: constraints} = bin_packer, fun_name, args) do
    constraints =
      Enum.map(constraints, fn {{module, _init_args} = constraint, state} ->
        {constraint, apply(module, fun_name, [bin_packer | args] ++ [state])}
      end)

    %BinPacker{bin_packer | constraints: constraints}
  end
end
