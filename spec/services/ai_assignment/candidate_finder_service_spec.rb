require "rails_helper"

RSpec.describe AiAssignment::CandidateFinderService do
  describe ".can_assign?" do
    let(:game) { double("Game", id: 1, latitude: 40.7128, longitude: -74.0060) }
    let(:official) { double("Official", id: 10, name: "John Doe") }
    let(:role) { "referee" }
    let(:assignments_relation) { double("Assignments") }

    before do
      allow(game).to receive(:assignments).and_return(assignments_relation)
    end

    context "when official cannot fill the role" do
      before do
        allow(official).to receive(:can_fill_role?).with(role).and_return(false)
      end

      it "returns not eligible with reason" do
        result = described_class.can_assign?(game: game, official: official, role: role)

        expect(result[:eligible]).to be false
        expect(result[:reason]).to include("cannot fill role")
      end
    end

    context "when official is already assigned to the game" do
      before do
        allow(official).to receive(:can_fill_role?).with(role).and_return(true)
        query = double("Query", exists?: true)
        allow(assignments_relation).to receive(:where).with(official: official).and_return(query)
      end

      it "returns not eligible with reason" do
        result = described_class.can_assign?(game: game, official: official, role: role)

        expect(result[:eligible]).to be false
        expect(result[:reason]).to include("already assigned")
      end
    end

    context "when distance exceeds official's maximum" do
      before do
        allow(official).to receive(:can_fill_role?).with(role).and_return(true)
        query = double("Query", exists?: false)
        allow(assignments_relation).to receive(:where).with(official: official).and_return(query)
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
          .with(game, official)
          .and_return(false)
        allow(DistanceCalculationService).to receive(:between_game_and_official)
          .with(game, official)
          .and_return(75.5)
      end

      it "returns not eligible with distance reason" do
        result = described_class.can_assign?(game: game, official: official, role: role)

        expect(result[:eligible]).to be false
        expect(result[:reason]).to include("75.5 miles")
        expect(result[:reason]).to include("exceeds")
      end
    end

    context "when official meets all requirements" do
      before do
        allow(official).to receive(:can_fill_role?).with(role).and_return(true)
        query = double("Query", exists?: false)
        allow(assignments_relation).to receive(:where).with(official: official).and_return(query)
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
          .with(game, official)
          .and_return(true)
      end

      it "returns eligible" do
        result = described_class.can_assign?(game: game, official: official, role: role)

        expect(result[:eligible]).to be true
        expect(result[:reason]).to include("meets all requirements")
      end
    end

    context "when game has no coordinates" do
      let(:game_no_coords) { double("Game", id: 1, latitude: nil, longitude: nil) }

      before do
        allow(game_no_coords).to receive(:assignments).and_return(assignments_relation)
        allow(official).to receive(:can_fill_role?).with(role).and_return(true)
        query = double("Query", exists?: false)
        allow(assignments_relation).to receive(:where).with(official: official).and_return(query)
        # Set up spy for distance service
        allow(DistanceCalculationService).to receive(:within_travel_distance?)
      end

      it "skips distance check and returns eligible" do
        result = described_class.can_assign?(game: game_no_coords, official: official, role: role)

        expect(result[:eligible]).to be true
        expect(DistanceCalculationService).not_to have_received(:within_travel_distance?)
      end
    end
  end

  # Note: Testing .find_candidates and .find_candidates_for_roles would require
  # ActiveRecord integration tests or more complex mocking. These methods are
  # better tested through integration/feature tests that use the actual database.
  # The core logic is tested through .can_assign? which exercises the same
  # business rules.
end
