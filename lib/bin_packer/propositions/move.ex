defmodule BinPacker.MoveProposition do
  @moduledoc false

  alias BinPacker.Assignments
  alias BinPacker.Proposition

  defstruct [
    :ball_id,
    :from_bin_id,
    :to_bin_id
  ]

  # TODO: raise when from_bin_id == to_bin_id
  def new(bin_packer, ball_id, to_bin_id) do
    from_bin_id = Assignments.bin_id(bin_packer, ball_id)

    %__MODULE__{
      ball_id: ball_id,
      from_bin_id: from_bin_id,
      to_bin_id: to_bin_id
    }
  end

  defimpl Proposition do
    def valid?(%@for{ball_id: ball_id, from_bin_id: from_bin_id, to_bin_id: to_bin_id}, bin_packer) do
      from_bin_id != to_bin_id &&
      from_bin_id == Assignments.bin_id(bin_packer, ball_id)
    end

    def execute(%@for{ball_id: ball_id, from_bin_id: from_bin_id, to_bin_id: to_bin_id}, bin_packer) do
      Assignments.move_ball_id(bin_packer, ball_id, from_bin_id, to_bin_id)
    end
  end
end
