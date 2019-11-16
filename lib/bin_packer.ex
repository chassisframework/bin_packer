defmodule BinPacker do
  alias BinPacker.Assignments
  alias BinPacker.Ball
  alias BinPacker.Bin
  alias BinPacker.Diff

  alias BinPacker.MoveProposition
  alias BinPacker.SwapProposition

  alias BinPacker.Neighbourhood
  alias BinPacker.MoveNeighbourhood
  alias BinPacker.SwapNeighbourhood

  alias BinPacker.Constraint
  alias BinPacker.DummyConstraint
  alias BinPacker.Objective

  @default_neighbourhoods %{
    MoveNeighbourhood => %{max_bins: 100, max_balls: 1000},
    SwapNeighbourhood => %{max_swaps: 100}
  }
  @default_constraints [{DummyConstraint, []}]

  defstruct objectives: Map.new(),
            neighbourhoods: Map.new(),
            constraints: [],
            assignments: %Assignments{}

  @type id :: any
  @type bin_id :: id
  @type ball_id :: id
  @type ball_ids :: [ball_id]
  @type bin_ids :: [bin_id]

  @type cost :: number

  @type state :: any
  @type args :: any
  @type ma :: {module, args}

  @type weight :: number
  @type objective_opts :: %{required(ma) => weight}
  @type objectives :: %{required({ma, state}) => weight}

  @type neighbourhood_opts :: %{module => args}
  @type neighbourhoods :: %{required(ma) => state}

  @type constraint_opts :: [ma]
  @type constraints :: [{ma, state}]

  @type proposition :: MoveProposition.t() | SwapProposition.t()
  @type propositions :: [propositions]

  @type proposition_type :: MoveProposition | SwapProposition
  @type proposition_types :: [proposition_types]

  @type search_opts :: [{:neighbourhoods, neighbourhood_opts} | {:constraints, constraint_opts}]

  @type t ::
          %__MODULE__{
            objectives: Objectives.t(),
            neighbourhoods: neighbourhoods,
            constraints: constraints,
            assignments: Assignments.t()
          }

  @spec new([Bin.t()], [Ball.t()], objective_opts, search_opts) :: t
  def new(bins, balls, objectives, opts \\ [])
      when is_list(bins) and
           is_list(balls) and
           is_map(objectives) and
           is_list(opts) do
    neighbourhoods = Keyword.get(opts, :neighbourhoods, @default_neighbourhoods)
    constraints =
      opts
      |> Keyword.get(:constraints, @default_constraints)
      |> case do
           [] ->
             @default_constraints
           constraints ->
             constraints
         end

    %__MODULE__{}
    |> Neighbourhood.initialize(neighbourhoods)
    |> initialize_constraints(constraints)
    |> Objective.initialize(objectives)
    |> add_bins(bins)
    |> add_balls(balls)
  end

  defp initialize_constraints(%__MODULE__{} = bin_packer, constraints) do
    constraints =
      Enum.map(constraints, fn {module, args} = constraint ->
        {constraint, module.init(args)}
      end)

    %__MODULE__{bin_packer | constraints: constraints}
  end

  #
  # TODO: proper error
  #
  @spec add_bin(t, Bin.t()) :: t
  def add_bin(%__MODULE__{} = bin_packer, bin) do
    if Assignments.has_bin?(bin_packer, bin) do
      raise "refusing to add bin #{inspect bin}', already present"
    end

    bin_packer
    |> Assignments.put_bin(bin)
    |> Objective.bin_added(bin)
    |> Constraint.bin_added(bin)
  end

  @spec add_bins(t, [Bin.t()]) :: t
  def add_bins(%__MODULE__{} = bin_packer, bins) when is_list(bins) do
    Enum.reduce(bins, bin_packer, &add_bin(&2, &1))
  end

  #
  # TODO
  # - proper errors
  #
  @spec add_ball(t, Ball.t()) :: t
  def add_ball(%__MODULE__{constraints: []} = bin_packer, ball) do
    bin_ids = Assignments.bin_ids(bin_packer)

    place_ball_in_lowest_cost_bin(bin_packer, ball, bin_ids)
  end

  def add_ball(%__MODULE__{constraints: [{{first_constraint, _init_args}, constraint_state} | other_constraints]} = bin_packer, ball) do
    if Assignments.has_ball?(bin_packer, ball) do
      raise "refusing to add ball '#{inspect ball}', already present"
    end

    bin_packer
    |> first_constraint.propose_new_placements(ball, constraint_state)
    |> Enum.filter(&Constraint.valid_new_placement?(other_constraints, bin_packer, ball, &1))
    |> case do
        [] ->
          raise "unable to add ball '#{inspect ball}', unable to find a bin that satisfies all constraints"

        bin_ids ->
          place_ball_in_lowest_cost_bin(bin_packer, ball, bin_ids)
       end
  end

  @spec add_balls(t, [Ball.t()]) :: t
  def add_balls(%__MODULE__{} = bin_packer, balls) when is_list(balls) do
    Enum.reduce(balls, bin_packer, &add_ball(&2, &1))
  end

  defdelegate diff(bin_packer, other_bin_packer), to: Diff
  defdelegate to_map(bin_packer), to: Assignments
  defdelegate cost(bin_packer), to: Objective
  defdelegate search(bin_packer, opts \\ []), to: Neighbourhood

  defp place_ball(bin_packer, bin_id, ball) do
    bin_packer
    |> Assignments.put_ball(bin_id, ball)
    |> Objective.ball_added(ball)
    |> Constraint.ball_added(ball)
  end

  defp place_ball_in_lowest_cost_bin(bin_packer, ball, [bin_id]) do
    place_ball(bin_packer, bin_id, ball)
  end

  defp place_ball_in_lowest_cost_bin(bin_packer, ball, [bin_id | bin_ids]) do
    lowest_cost_bin_packer = place_ball(bin_packer, bin_id, ball)
    lowest_cost = cost(lowest_cost_bin_packer)

    bin_ids
    |> Enum.reduce({lowest_cost, lowest_cost_bin_packer}, fn bin_id, {lowest_cost, _lowest_bin_packer} = acc ->
        bin_packer = place_ball(bin_packer, bin_id, ball)
        cost = cost(bin_packer)

        if cost < lowest_cost do
          {cost, bin_packer}
        else
          acc
        end
      end)
    |> fn {_cost, bin_packer} -> bin_packer end.()
  end
end
