defmodule BinPacker.Assignments do

  alias BinPacker, as: BinPacker
  alias BinPacker.Ball
  alias BinPacker.Bin

  defstruct bins: Map.new(),
            balls: Map.new(),
            # bin has many balls
            bin_id_to_ball_ids: Map.new(),
            # ball belongs to one bin
            ball_id_to_bin_id: Map.new()

  @type id :: BinPacker.id()
  @type bin_id :: BinPacker.bin_id()
  @type ball_id :: BinPacker.ball_id()

  @type bins :: %{required(bin_id) => Bin.t()}
  @type balls :: %{required(ball_id) => Ball.t()}

  @type bin_id_to_ball_ids :: %{required(bin_id) => MapSet.t(ball_id)}
  @type ball_id_to_bin_id :: %{required(ball_id) => bin_id}

  @type t :: %__MODULE__{
          bins: bins,
          balls: balls,
          bin_id_to_ball_ids: bin_id_to_ball_ids,
          ball_id_to_bin_id: ball_id_to_bin_id
        }

  @spec bins(BinPacker.t) :: [Bin.t()]
  def bins(%BinPacker{assignments: %__MODULE__{bins: bins}}) do
    Map.values(bins)
  end

  @spec bin_ids(BinPacker.t) :: [bin_id]
  def bin_ids(%BinPacker{assignments: %__MODULE__{bins: bins}}) do
    Map.keys(bins)
  end

  @spec get_bin(BinPacker.t, bin_id) :: [Bin.t()]
  def get_bin(%BinPacker{assignments: %__MODULE__{bins: bins}}, id) do
    Map.get(bins, id)
  end

  @spec balls(BinPacker.t) :: [Ball.t()]
  def balls(%BinPacker{assignments: %__MODULE__{balls: balls}}) do
    Map.values(balls)
  end

  @spec ball_ids(BinPacker.t) :: [ball_id]
  def ball_ids(%BinPacker{assignments: %__MODULE__{balls: balls}}) do
    Map.keys(balls)
  end

  @spec get_ball(BinPacker.t, ball_id) :: [Ball.t()]
  def get_ball(%BinPacker{assignments: %__MODULE__{balls: balls}}, id) do
    Map.get(balls, id)
  end

  @spec has_bin?(BinPacker.t, Bin.t()) :: boolean
  def has_bin?(%BinPacker{assignments: %__MODULE__{bins: bins}}, bin) do
    Map.has_key?(bins, Bin.id(bin))
  end

  @spec has_ball?(BinPacker.t, Ball.t()) :: boolean
  def has_ball?(%BinPacker{assignments: %__MODULE__{balls: balls}}, ball) do
    Map.has_key?(balls, Ball.id(ball))
  end

  @spec bin_id(BinPacker.t, ball_id) :: bin_id
  def bin_id(%BinPacker{assignments: %__MODULE__{ball_id_to_bin_id: ball_id_to_bin_id}}, ball_id) do
    Map.fetch!(ball_id_to_bin_id, ball_id)
  end

  @spec bin_id_for_ball_id(BinPacker.t, ball_id) :: [Bin.t()]
  def bin_id_for_ball_id(%BinPacker{assignments: %__MODULE__{ball_id_to_bin_id: ball_id_to_bin_id}}, ball_id) do
    Map.fetch!(ball_id_to_bin_id, ball_id)
  end

  @spec bin_for_ball_id(BinPacker.t, ball_id) :: [Bin.t()]
  def bin_for_ball_id(%BinPacker{assignments: %__MODULE__{bins: bins}} = bin_packer, ball_id) do
    bin_id = bin_id_for_ball_id(bin_packer, ball_id)
    Map.fetch!(bins, bin_id)
  end

  @spec bin_for_ball(BinPacker.t, Ball.t()) :: [Bin.t()]
  def bin_for_ball(%BinPacker{} = bin_packer, ball) do
    bin_for_ball_id(bin_packer, Ball.id(ball))
  end

  @spec ball_ids_for_bin_id(BinPacker.t, bin_id) :: MapSet.t(bin_id)
  def ball_ids_for_bin_id(%BinPacker{assignments: %__MODULE__{bin_id_to_ball_ids: bin_id_to_ball_ids}}, bin_id) do
    Map.fetch!(bin_id_to_ball_ids, bin_id)
  end

  @spec balls_for_bin_id(BinPacker.t, bin_id) :: [Ball.t()]
  def balls_for_bin_id(%BinPacker{assignments: %__MODULE__{balls: balls}} = bin_packer, bin_id) do
    bin_packer
    |> ball_ids_for_bin_id(bin_id)
    |> Enum.map(fn ball_id ->
      Map.fetch!(balls, ball_id)
    end)
  end

  @spec put_bin(BinPacker.t, Bin.t()) :: BinPacker.t
  def put_bin(bin_packer, bin) do
    update(bin_packer, fn %__MODULE__{bins: bins, bin_id_to_ball_ids: bin_id_to_ball_ids} = assignments ->
      id = Bin.id(bin)

      %__MODULE__{assignments |
                  bins: Map.put(bins, id, bin),
                  bin_id_to_ball_ids: Map.put_new(bin_id_to_ball_ids, id, MapSet.new())}
    end)
  end

  @spec put_ball(BinPacker.t, bin_id, Ball.t()) :: BinPacker.t
  def put_ball(bin_packer, bin_id, ball) do
    update(bin_packer, fn %__MODULE__{balls: balls,
                                           bin_id_to_ball_ids: bin_id_to_ball_ids,
                                           ball_id_to_bin_id: ball_id_to_bin_id} = assignments ->
      id = Ball.id(ball)

      bin_id_to_ball_ids =
        Map.update!(bin_id_to_ball_ids, bin_id, fn ball_ids ->
          MapSet.put(ball_ids, id)
        end)

      ball_id_to_bin_id = Map.put(ball_id_to_bin_id, id, bin_id)

      %__MODULE__{assignments |
                  balls: Map.put(balls, id, ball),
                  bin_id_to_ball_ids: bin_id_to_ball_ids,
                  ball_id_to_bin_id: ball_id_to_bin_id}
    end)
  end

  @spec move_ball_id(BinPacker.t, ball_id, bin_id, bin_id) :: BinPacker.t
  def move_ball_id(
    bin_packer,
    ball_id,
    from_bin_id,
    to_bin_id
  ) do
    update(bin_packer, fn %__MODULE__{bin_id_to_ball_ids: bin_id_to_ball_ids,
                                   ball_id_to_bin_id: ball_id_to_bin_id} = assignments ->
      {^from_bin_id, ball_id_to_bin_id} = Map.pop(ball_id_to_bin_id, ball_id)
      ball_id_to_bin_id = Map.put(ball_id_to_bin_id, ball_id, to_bin_id)

      bin_id_to_ball_ids =
        bin_id_to_ball_ids
        |> Map.update!(from_bin_id, fn ball_ids ->
          MapSet.delete(ball_ids, ball_id)
        end)
        |> Map.update!(to_bin_id, fn ball_ids ->
          MapSet.put(ball_ids, ball_id)
        end)

      %__MODULE__{assignments |
                  bin_id_to_ball_ids: bin_id_to_ball_ids,
                  ball_id_to_bin_id: ball_id_to_bin_id}
    end)
  end

  @spec to_map(BinPacker.t()) :: %{required(Bin.t()) => [Ball.t()]}
  def to_map(%BinPacker{assignments: %__MODULE__{
                         bin_id_to_ball_ids: bin_id_to_ball_ids,
                         balls: balls,
                         bins: bins}}) do
    Enum.into(bin_id_to_ball_ids, %{}, fn {bin_id, ball_ids} ->
      balls_in_bin = Enum.map(ball_ids, &Map.fetch!(balls, &1))
      bin = Map.fetch!(bins, bin_id)

      {bin, balls_in_bin}
    end)
  end

  defp update(%BinPacker{assignments: assignments} = bin_packer, fun) do
    %BinPacker{bin_packer | assignments: fun.(assignments)}
  end
end
