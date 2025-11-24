require "rails_helper"

RSpec.describe Ollama::PromptBuilderService do
  describe ".build_single_game_data" do
    let(:game) { double("Game", id: 1, name: "Test Game") }
    let(:official1) { double("Official", id: 10, name: "John Doe") }
    let(:official2) { double("Official", id: 20, name: "Jane Smith") }
    let(:officials) { [official1, official2] }
    let(:assignment) { double("Assignment", role: "referee", official: double(name: "Bob")) }

    before do
      allow(game).to receive(:open_positions).and_return(["umpire", "linesman"])
      allow(game).to receive(:assignments).and_return(double(includes: [assignment]))

      # Mock build_official_data for each official
      allow(described_class).to receive(:build_official_data).with(official: official1, game: game, distance_matrix: {})
        .and_return({ id: 10, name: "John Doe", roles: "REFEREE", distance_text: "5.0 miles" })
      allow(described_class).to receive(:build_official_data).with(official: official2, game: game, distance_matrix: {})
        .and_return({ id: 20, name: "Jane Smith", roles: "UMPIRE", distance_text: "10.0 miles" })

      # Mock format_officials_text
      allow(described_class).to receive(:format_officials_text).and_return("Formatted officials text")
    end

    it "builds single game data structure" do
      result = described_class.build_single_game_data(game: game, officials: officials)

      expect(result[:game]).to eq(game)
      expect(result[:open_positions]).to eq(["umpire", "linesman"])
      expect(result[:assigned_roles]).to eq("REFEREE: Bob")
      expect(result[:officials]).to be_an(Array)
      expect(result[:officials].length).to eq(2)
      expect(result[:officials_text]).to eq("Formatted officials text")
    end

    it "passes distance_matrix to build_official_data" do
      distance_matrix = { "1_10" => 5.5, "1_20" => 12.3 }

      allow(described_class).to receive(:build_official_data).with(official: official1, game: game, distance_matrix: distance_matrix)
        .and_return({ id: 10 })
      allow(described_class).to receive(:build_official_data).with(official: official2, game: game, distance_matrix: distance_matrix)
        .and_return({ id: 20 })

      result = described_class.build_single_game_data(game: game, officials: officials, distance_matrix: distance_matrix)

      expect(result[:officials].length).to eq(2)
    end
  end

  describe ".build_official_data" do
    let(:game) { double("Game", id: 1, game_date: Time.zone.now) }
    let(:official_role1) { double("OfficialRole", role: "referee") }
    let(:official_role2) { double("OfficialRole", role: "umpire") }
    let(:rule1) { double("Rule", rule_text: "Prefer local games") }
    let(:active_rules) { [rule1] }
    let(:assignments) { double("Assignments", count: 3) }

    let(:official) do
      double("Official",
        id: 10,
        name: "John Doe",
        home_address: "123 Main St",
        official_roles: [official_role1, official_role2],
        max_distance: 50,
        assignments: assignments,
        rules: double(active: active_rules),
        available_for_game?: true,
        availabilities: []
      )
    end

    context "with distance matrix" do
      let(:distance_matrix) { { "1_10" => 25.5 } }

      before do
        allow(active_rules).to receive(:map).and_yield(rule1).and_return(["Prefer local games"])
      end

      it "uses pre-calculated distance from matrix" do
        expect(DistanceCalculationService).not_to receive(:between_game_and_official)

        result = described_class.build_official_data(official: official, game: game, distance_matrix: distance_matrix)

        expect(result[:distance]).to eq(25.5)
        expect(result[:distance_text]).to eq("25.5 miles")
      end
    end

    context "without distance matrix" do
      before do
        allow(active_rules).to receive(:map).and_yield(rule1).and_return(["Prefer local games"])
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official)
          .and_return(15.8)
      end

      it "calculates distance on the fly" do
        result = described_class.build_official_data(official: official, game: game)

        expect(result[:distance]).to eq(15.8)
        expect(result[:distance_text]).to eq("15.8 miles")
      end
    end

    context "when distance is nil" do
      before do
        allow(active_rules).to receive(:map).and_yield(rule1).and_return(["Prefer local games"])
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official)
          .and_return(nil)
      end

      it "returns 'Distance unknown'" do
        result = described_class.build_official_data(official: official, game: game)

        expect(result[:distance]).to be_nil
        expect(result[:distance_text]).to eq("Distance unknown")
      end
    end

    context "with complete official data" do
      before do
        allow(active_rules).to receive(:map).and_yield(rule1).and_return(["Prefer local games"])
        allow(DistanceCalculationService).to receive(:between_game_and_official).and_return(10.0)
      end

      it "builds complete official data structure" do
        result = described_class.build_official_data(official: official, game: game)

        expect(result[:id]).to eq(10)
        expect(result[:name]).to eq("John Doe")
        expect(result[:home_address]).to eq("123 Main St")
        expect(result[:roles]).to eq("REFEREE, UMPIRE")
        expect(result[:max_distance]).to eq(50)
        expect(result[:current_assignments]).to eq(3)
        expect(result[:distance]).to eq(10.0)
        expect(result[:distance_text]).to eq("10.0 miles")
        expect(result[:rules]).to eq("Prefer local games")
        expect(result[:has_rules]).to be true
      end
    end

    context "with minimal official data" do
      let(:minimal_official) do
        double("Official",
          id: 20,
          name: "Jane Smith",
          home_address: nil,
          official_roles: [official_role1],
          max_distance: nil,
          assignments: double(count: 0),
          rules: double(active: []),
          available_for_game?: true,
          availabilities: []
        )
      end

      before do
        allow(DistanceCalculationService).to receive(:between_game_and_official).and_return(5.0)
      end

      it "handles nil values appropriately" do
        result = described_class.build_official_data(official: minimal_official, game: game)

        expect(result[:home_address]).to eq("Not specified")
        expect(result[:max_distance]).to eq("No limit")
        expect(result[:current_assignments]).to eq(0)
        expect(result[:rules]).to eq("")
        expect(result[:has_rules]).to be false
      end
    end
  end
end
