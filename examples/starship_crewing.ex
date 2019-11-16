defmodule StarshipCrewingExample do
  alias BinPacker.OnePerBinConstraint
  alias BinPacker.BallsProportionalToBinObjective

  import BinPacker.Util, only: [sum_by: 2]

  defmodule Ship do
    defstruct [
      :name,
      :size
    ]

    defimpl BinPacker.Bin do
      def id(%@for{name: name}), do: name
      def attribute(%@for{size: size}, _attribute), do: size
      def attribute(%@for{}, _attribute), do: raise "not implemented"
    end
  end

  defmodule CrewMember do
    defstruct [
      :name,
      :profession,
      attributes: Map.new()
    ]

    defimpl BinPacker.Ball do
      def id(%@for{name: name}), do: name
      def attribute(%@for{profession: profession}, :profession), do: profession
      def attribute(%@for{attributes: attributes}, attribute), do: Map.get(attributes, attribute)
    end
  end

  def new do
    ships = [
      %Ship{name: "USS Enterprise", size: 49},
      %Ship{name: "USS Bellerephon", size: 42},
      %Ship{name: "USS Melbourne", size: 35},
      %Ship{name: "USS Kyushu", size: 28},
      %Ship{name: "USS Princeton", size: 21},
      %Ship{name: "USS Bonestell", size: 14},
      %Ship{name: "USS Tolstoy", size: 7}
    ]

    first_names = [
      "Jean Luc",
      "William",
      "Deanna",
      "Geordi",
      "Worf",
      "Beverly",
      "Data",
    ]

    last_names = [
      "Picard",
      "Riker",
      "Troi",
      "La Forge",
      "Worf",
      "Crusher",
      "Data",
    ]

    professions = [
      :captain,
      :first_officer,
      :counselor,
      :engineer,
      :security,
      :doctor,
      :helmsman
    ]

    crew =
      first_names
      |> Enum.with_index(1)
      |> Enum.reverse
      |> Enum.flat_map(fn {first_name, i} ->
        Enum.map(last_names, fn last_name ->
          %CrewMember{name: first_name <> " " <> last_name,
                      attributes: %{
                        competency: i,
                        empathy: i,
                        aggressiveness: i,
                      }}
        end)
      end)
      |> Enum.zip(Stream.cycle(professions))
      |> Enum.map(fn {crew_member, profession} ->
        %CrewMember{crew_member | profession: profession}
      end)

    BinPacker.new(
      ships,
      crew,
      %{
        {BallsProportionalToBinObjective, [ball_attribute: :competency, bin_attribute: :size]} => 10,
        # {BallsProportionalToBinObjective, [ball_attribute: :empathy, bin_attribute: :size]} => 1,
        # {BallsProportionalToBinObjective, [ball_attribute: :aggressiveness, bin_attribute: :size]} => 1
      },
      constraints: [
        {OnePerBinConstraint, :profession}
      ]
    )
  end

  def optimize(bin_packer) do
    BinPacker.search(bin_packer)
  end

  def pretty_print(bin_packer) do
    bin_packer
    |> BinPacker.to_map()
    |> Enum.sort_by(fn {%Ship{size: ship_size}, _crew} -> ship_size end)
    |> Enum.each(fn {%Ship{name: ship_name, size: ship_size}, crew} ->
      total_competency = sum_by(crew, fn %CrewMember{attributes: %{competency: competency}} -> competency end)
      # total_empathy = sum_by(crew, fn %CrewMember{attributes: %{empathy: empathy}} -> empathy end)
      # total_aggressiveness = sum_by(crew, fn %CrewMember{attributes: %{aggressiveness: aggressiveness}} -> aggressiveness end)

      IO.puts "#{ship_name} (size: #{ship_size}, competency: #{total_competency})"

      crew
      |> Enum.sort_by(fn %CrewMember{profession: profession} -> profession end)
      |> Enum.each(fn %CrewMember{name: name, profession: _profession} = c ->
        IO.puts "-- #{name} (competency: #{c.attributes.competency})"
        # IO.puts "-- #{name} (#{profession})"
      end)

      IO.puts ""
    end)
  end

  def run do
    s = new()
    s = optimize(s)
    pretty_print(s)
    s
  end
end
