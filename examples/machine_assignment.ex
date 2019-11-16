defmodule MachineAssignmentExample do
  alias BinPacker.OnePerGroupConstraint
  alias BinPacker.BallsProportionalToBinObjective
  alias BinPacker.EqualDistributionPerBinObjective

  defmodule Machine do
    defstruct [
      :name,
      :location,
      capacities: Map.new()
    ]

    defimpl BinPacker.Bin do
      def id(%@for{location: location, name: name}), do: {location, name}
      def attribute(%@for{location: location}, :location), do: location
      def attribute(%@for{capacities: capacities}, capacity), do: Map.get(capacities, capacity)
    end
  end

  defmodule Process do
    defstruct [
      :name,
      :service,
      :is_master,
      usages: Map.new()
    ]

    defimpl BinPacker.Ball do
      def id(%@for{service: service, name: name}), do: {service, name}
      def attribute(%@for{service: service}, :service), do: service
      def attribute(%@for{is_master: is_master}, :is_master), do: is_master
      def attribute(%@for{usages: usages}, usage), do: Map.get(usages, usage)
    end
  end

  def new do
    machines = [
      %Machine{name: machine_name(1, 1), location: dc_name(1), capacities: %{cpu: 1500}},
      %Machine{name: machine_name(1, 2), location: dc_name(1), capacities: %{cpu: 150}},
      %Machine{name: machine_name(2, 1), location: dc_name(2), capacities: %{cpu: 100}},
      %Machine{name: machine_name(2, 2), location: dc_name(2), capacities: %{cpu: 100}},
      %Machine{name: machine_name(3, 1), location: dc_name(3), capacities: %{cpu: 100}},
      %Machine{name: machine_name(3, 2), location: dc_name(3), capacities: %{cpu: 100}},
      %Machine{name: machine_name(4, 1), location: dc_name(4), capacities: %{cpu: 100}},
      %Machine{name: machine_name(4, 2), location: dc_name(4), capacities: %{cpu: 100}},
      %Machine{name: machine_name(5, 1), location: dc_name(5), capacities: %{cpu: 50}},
      %Machine{name: machine_name(5, 2), location: dc_name(5), capacities: %{cpu: 50}}
    ]

    processes =
      Enum.flat_map(1..9, fn service_num ->
        service = "service-#{service_num}"

        Enum.map(1..3, fn replica_num ->
          %Process{name: "replica-#{replica_num}", service: service, is_master: replica_num == 1, usages: %{load: 10}}
        end)
      end)

    BinPacker.new(machines,
      processes,
      %{
        {BallsProportionalToBinObjective, [ball_attribute: :load, bin_attribute: :cpu]} => 1,
        {EqualDistributionPerBinObjective, :is_master} => 1

      },
      constraints: [
        {OnePerGroupConstraint, [ball_attribute: :service, bin_attribute: :location]}
      ])
  end

  def add_machine(bin_packer) do
    dc_num = Enum.random(1..5)
    dc = dc_name(dc_num)

    machine_num =
      bin_packer
      |> BinPacker.to_map()
      |> Map.keys()
      |> Enum.group_by(fn %Machine{location: location} -> location end)
      |> Map.get(dc, [])
      |> Enum.count()
      |> Kernel.+(1)

    machine = %Machine{name: machine_name(dc_num, machine_num), location: dc, capacities: %{cpu: 50}}

    BinPacker.add_bin(bin_packer, machine)
  end

  def optimize(bin_packer) do
    BinPacker.search(bin_packer)
  end

  defp machine_name(dc_num, machine_num) do
    "box-#{dc_name(dc_num)}-n#{machine_num}"
  end

  defp dc_name(dc_num) do
    "dc#{dc_num}"
  end
end
