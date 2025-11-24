require "rails_helper"

RSpec.describe AiAssignment::EligibilityFilterService do
  describe ".filter_eligible_officials" do
    let(:official1) { double("Official 1", id: 1, name: "John") }
    let(:official2) { double("Official 2", id: 2, name: "Jane") }
    let(:official3) { double("Official 3", id: 3, name: "Bob") }
    let(:officials) { [official1, official2, official3] }
    let(:open_positions) { ["referee", "umpire"] }

    context "when officials can fill positions" do
      before do
        allow(official1).to receive(:can_fill_role?).with("referee").and_return(true)
        allow(official1).to receive(:can_fill_role?).with("umpire").and_return(false)
        allow(official2).to receive(:can_fill_role?).with("referee").and_return(false)
        allow(official2).to receive(:can_fill_role?).with("umpire").and_return(true)
        allow(official3).to receive(:can_fill_role?).with("referee").and_return(false)
        allow(official3).to receive(:can_fill_role?).with("umpire").and_return(false)
      end

      it "returns only officials who can fill at least one position" do
        result = described_class.filter_eligible_officials(officials, open_positions)

        expect(result).to include(official1, official2)
        expect(result).not_to include(official3)
      end
    end

    context "when no officials can fill positions" do
      before do
        officials.each do |official|
          allow(official).to receive(:can_fill_role?).and_return(false)
        end
      end

      it "returns empty array" do
        result = described_class.filter_eligible_officials(officials, open_positions)

        expect(result).to be_empty
      end
    end

    context "with empty open positions" do
      it "returns empty array" do
        result = described_class.filter_eligible_officials(officials, [])

        expect(result).to be_empty
      end
    end
  end

  describe ".build_distance_matrix" do
    let(:game1) { double("Game 1", id: 1, latitude: 40.7128, longitude: -74.0060) }
    let(:game2) { double("Game 2", id: 2, latitude: nil, longitude: nil) }
    let(:official1) { double("Official 1", id: 10) }
    let(:official2) { double("Official 2", id: 20) }
    let(:games) { [game1, game2] }
    let(:officials) { [official1, official2] }

    before do
      allow(DistanceCalculationService).to receive(:between_game_and_official)
        .with(game1, official1).and_return(15.5)
      allow(DistanceCalculationService).to receive(:between_game_and_official)
        .with(game1, official2).and_return(25.3)
    end

    it "builds distance matrix for games with coordinates" do
      result = described_class.build_distance_matrix(games, officials)

      expect(result["1_10"]).to eq(15.5)
      expect(result["1_20"]).to eq(25.3)
      expect(result["2_10"]).to be_nil
      expect(result["2_20"]).to be_nil
    end

    it "skips games without coordinates" do
      result = described_class.build_distance_matrix(games, officials)

      expect(result).not_to have_key("2_10")
      expect(result).not_to have_key("2_20")
    end

    context "with empty inputs" do
      it "returns empty hash for empty games" do
        result = described_class.build_distance_matrix([], officials)

        expect(result).to eq({})
      end

      it "returns empty hash for empty officials" do
        result = described_class.build_distance_matrix(games, [])

        expect(result).to eq({})
      end
    end
  end

  describe ".filter_with_details" do
    let(:game) { double("Game", id: 1, latitude: 40.7128, longitude: -74.0060, game_date: Time.zone.now) }
    let(:official1) { double("Official 1", id: 10, name: "John") }
    let(:official2) { double("Official 2", id: 20, name: "Jane") }
    let(:official3) { double("Official 3", id: 30, name: "Bob") }
    let(:official4) { double("Official 4", id: 40, name: "Alice") }
    let(:officials) { [official1, official2, official3, official4] }
    let(:open_positions) { ["referee", "umpire"] }
    let(:assignments_relation) { double("Assignments") }

    before do
      allow(game).to receive(:assignments).and_return(assignments_relation)
    end

    context "with mixed eligibility" do
      before do
        # Official 1: Can fill referee, within distance, not assigned - ELIGIBLE
        allow(official1).to receive(:can_fill_role?).with("referee").and_return(true)
        allow(official1).to receive(:can_fill_role?).with("umpire").and_return(false)
        allow(official1).to receive(:available_for_game?).with(game).and_return(true)
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
          .with(game, official1).and_return(true)
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official1).and_return(10.0)
        allow(assignments_relation).to receive(:where).with(official: official1)
          .and_return(double(exists?: false))

        # Official 2: Cannot fill any position - INELIGIBLE
        allow(official2).to receive(:can_fill_role?).and_return(false)

        # Official 3: Can fill umpire but exceeds distance - INELIGIBLE
        allow(official3).to receive(:can_fill_role?).with("referee").and_return(false)
        allow(official3).to receive(:can_fill_role?).with("umpire").and_return(true)
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
          .with(game, official3).and_return(false)
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official3).and_return(75.5)

        # Official 4: Can fill referee, within distance, but already assigned - INELIGIBLE
        allow(official4).to receive(:can_fill_role?).with("referee").and_return(true)
        allow(official4).to receive(:can_fill_role?).with("umpire").and_return(true)
        allow(official4).to receive(:available_for_game?).with(game).and_return(true)
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
          .with(game, official4).and_return(true)
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official4).and_return(20.0)
        allow(assignments_relation).to receive(:where).with(official: official4)
          .and_return(double(exists?: true))
      end

      it "correctly categorizes eligible officials" do
        result = described_class.filter_with_details(officials, game: game, open_positions: open_positions)

        expect(result[:eligible].length).to eq(1)
        expect(result[:eligible][0][:official]).to eq(official1)
        expect(result[:eligible][0][:can_fill_positions]).to eq(["referee"])
        expect(result[:eligible][0][:distance]).to eq(10.0)
      end

      it "correctly categorizes ineligible officials with reasons" do
        result = described_class.filter_with_details(officials, game: game, open_positions: open_positions)

        expect(result[:ineligible].length).to eq(3)

        # Check reasons
        reasons = result[:ineligible].map { |r| r[:reason] }
        expect(reasons).to include(match(/Cannot fill any open positions/))
        expect(reasons).to include(match(/Distance.*75.5 miles.*exceeds/))
        expect(reasons).to include(match(/Already assigned/))
      end

      it "includes summary statistics" do
        result = described_class.filter_with_details(officials, game: game, open_positions: open_positions)

        expect(result[:summary][:total]).to eq(4)
        expect(result[:summary][:eligible_count]).to eq(1)
        expect(result[:summary][:ineligible_count]).to eq(3)
      end
    end

    context "when game has no coordinates" do
      let(:game_no_coords) { double("Game", id: 2, latitude: nil, longitude: nil, game_date: Time.zone.now) }

      before do
        allow(game_no_coords).to receive(:assignments).and_return(assignments_relation)

        # Official can fill position and is not assigned
        allow(official1).to receive(:can_fill_role?).with("referee").and_return(true)
        allow(official1).to receive(:can_fill_role?).with("umpire").and_return(false)
        allow(official1).to receive(:available_for_game?).with(game_no_coords).and_return(true)
        allow(assignments_relation).to receive(:where).with(official: official1)
          .and_return(double(exists?: false))
        # Set up spy for distance services
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game_no_coords, official1).and_return(nil)
      end

      it "skips distance check" do
        result = described_class.filter_with_details([official1], game: game_no_coords, open_positions: open_positions)

        expect(result[:eligible].length).to eq(1)
        expect(result[:eligible][0][:official]).to eq(official1)
        expect(DistanceCalculationService).not_to have_received(:within_travel_distance?)
      end
    end

    context "with all eligible officials" do
      before do
        officials.each do |official|
          allow(official).to receive(:can_fill_role?).with("referee").and_return(true)
          allow(official).to receive(:can_fill_role?).with("umpire").and_return(false)
          allow(official).to receive(:available_for_game?).with(game).and_return(true)
          allow(DistanceCalculationService).to receive(:within_travel_distance?)
            .with(game, official).and_return(true)
          allow(DistanceCalculationService).to receive(:between_game_and_official)
            .with(game, official).and_return(10.0)
          allow(assignments_relation).to receive(:where).with(official: official)
            .and_return(double(exists?: false))
        end
      end

      it "returns all officials as eligible" do
        result = described_class.filter_with_details(officials, game: game, open_positions: open_positions)

        expect(result[:eligible].length).to eq(4)
        expect(result[:ineligible]).to be_empty
        expect(result[:summary][:eligible_count]).to eq(4)
        expect(result[:summary][:ineligible_count]).to eq(0)
      end
    end

    context "with all ineligible officials" do
      before do
        officials.each do |official|
          allow(official).to receive(:can_fill_role?).and_return(false)
        end
      end

      it "returns all officials as ineligible" do
        result = described_class.filter_with_details(officials, game: game, open_positions: open_positions)

        expect(result[:eligible]).to be_empty
        expect(result[:ineligible].length).to eq(4)
        expect(result[:summary][:eligible_count]).to eq(0)
        expect(result[:summary][:ineligible_count]).to eq(4)
      end
    end
  end
end
