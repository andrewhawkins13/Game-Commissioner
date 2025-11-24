require "rails_helper"

RSpec.describe Assignment, type: :model do
  describe "validations" do
    let(:game) do
      Game.create!(
        name: "Test Game",
        game_date: 1.day.from_now,
        location: "Stadium",
        address: "123 Test St",
        status: :scheduled
      )
    end
    let(:official) { Official.create!(name: "John Doe", email: "john@test.com") }
    let(:referee_role) { OfficialRole.create!(official: official, role: :referee) }
    let(:hl_role) { OfficialRole.create!(official: official, role: :hl) }

    before do
      # Ensure official has the roles
      referee_role
      hl_role
    end


    it "is valid with valid attributes" do
      assignment = Assignment.new(
        game: game,
        official: official,
        role: :referee,
        success: true
      )

      expect(assignment).to be_valid
    end

    context "duplicate prevention" do
      let!(:existing_assignment) do
        Assignment.create!(
          game: game,
          official: official,
          role: :referee,
          success: true
        )
      end

      it "prevents the same official from being assigned to the same game twice (different role)" do
        duplicate_assignment = Assignment.new(
          game: game,
          official: official,
          role: :hl,  # Different role, same official and game
          success: true
        )

        expect(duplicate_assignment).not_to be_valid
        expect(duplicate_assignment.errors[:official_id]).to include("is already assigned to this game")
      end

      it "prevents the same official from being assigned to the same game twice (same role)" do
        duplicate_assignment = Assignment.new(
          game: game,
          official: official,
          role: :referee,  # Same role, same official and game
          success: true
        )

        expect(duplicate_assignment).not_to be_valid
        expect(duplicate_assignment.errors[:role]).to include("has already been assigned for this game")
      end

      it "allows the same official to be assigned to different games" do
        different_game = Game.create!(
          name: "Different Game",
          game_date: 2.days.from_now,
          location: "Other Stadium",
          address: "456 Other St",
          status: :scheduled
        )

        another_assignment = Assignment.new(
          game: different_game,
          official: official,
          role: :referee,
          success: true
        )

        expect(another_assignment).to be_valid
      end

      it "only validates uniqueness for successful assignments" do
        # Failed assignments (success: false) should not trigger uniqueness validation
        failed_duplicate = Assignment.new(
          game: game,
          official: official,
          role: :hl,
          success: false
        )

        # This should be valid because success is false
        expect(failed_duplicate).to be_valid
      end
    end

    context "database constraint" do
      let!(:existing_assignment) do
        Assignment.create!(
          game: game,
          official: official,
          role: :referee,
          success: true
        )
      end

      it "database index prevents duplicate assignments at database level" do
        # Bypass ActiveRecord validations to test database constraint
        duplicate = Assignment.new(
          game: game,
          official: official,
          role: :hl,
          success: true
        )

        # Use save(validate: false) to bypass model validations
        expect {
          duplicate.save(validate: false)
        }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "associations" do
    it "belongs to a game" do
      expect(Assignment.reflect_on_association(:game).macro).to eq(:belongs_to)
    end

    it "belongs to an official" do
      expect(Assignment.reflect_on_association(:official).macro).to eq(:belongs_to)
    end

    it "belongs to an assignment attempt (optional)" do
      expect(Assignment.reflect_on_association(:assignment_attempt).macro).to eq(:belongs_to)
    end

    it "has many rule violations" do
      expect(Assignment.reflect_on_association(:rule_violations).macro).to eq(:has_many)
    end
  end

  describe "enums" do
    it "defines role enum" do
      expect(Assignment.defined_enums["role"]).to eq({
        "referee" => 0,
        "hl" => 1,
        "lj" => 2,
        "bj" => 3,
        "uc" => 4
      })
    end
  end
end
