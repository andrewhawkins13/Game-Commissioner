require "rails_helper"

RSpec.describe AiAssignment::AssignmentBuilderService do
  let(:game) { double("Game") }
  let(:official) { double("Official", id: 10, name: "John Doe") }
  let(:attempt) { double("AssignmentAttempt", id: 1) }
  let(:role) { "referee" }
  let(:assignments_relation) { double("AssignmentsRelation") }

  before do
    allow(game).to receive(:assignments).and_return(assignments_relation)
  end

  describe ".create_assignment" do
    let(:assignment) { double("Assignment", persisted?: true, errors: double(full_messages: [])) }

    before do
      allow(assignments_relation).to receive(:create).and_return(assignment)
    end

    it "creates an assignment with all attributes" do
      expect(assignments_relation).to receive(:create).with(
        official: official,
        role: role,
        assignment_attempt: attempt,
        score: 90,
        reasoning: "Excellent match",
        tokens_used: 100,
        duration_ms: 5000,
        ai_response: "AI response text",
        success: true
      )

      described_class.create_assignment(
        game: game,
        official: official,
        role: role,
        attempt: attempt,
        score: 90,
        reasoning: "Excellent match",
        tokens_used: 100,
        duration_ms: 5000,
        ai_response: "AI response text"
      )
    end

    context "when assignment is persisted successfully" do
      it "returns success result" do
        result = described_class.create_assignment(
          game: game,
          official: official,
          role: role,
          attempt: attempt,
          score: 90,
          reasoning: "Good match"
        )

        expect(result[:success]).to be true
        expect(result[:assignment]).to eq(assignment)
        expect(result[:score]).to eq(90)
        expect(result[:reasoning]).to eq("Good match")
      end
    end

    context "when assignment fails to persist" do
      let(:failed_assignment) do
        double("Assignment",
          persisted?: false,
          errors: double(full_messages: ["Official cannot be assigned"])
        )
      end

      before do
        allow(assignments_relation).to receive(:create).and_return(failed_assignment)
      end

      it "returns failure result with errors" do
        result = described_class.create_assignment(
          game: game,
          official: official,
          role: role,
          attempt: attempt,
          score: 90,
          reasoning: "Good match"
        )

        expect(result[:success]).to be false
        expect(result[:assignment]).to eq(failed_assignment)
        expect(result[:errors]).to eq(["Official cannot be assigned"])
      end
    end

    it "uses default values for optional parameters" do
      expect(assignments_relation).to receive(:create).with(
        hash_including(
          tokens_used: 0,
          duration_ms: 0,
          ai_response: nil
        )
      )

      described_class.create_assignment(
        game: game,
        official: official,
        role: role,
        attempt: attempt,
        score: 85,
        reasoning: "Match"
      )
    end
  end

  describe ".create_failed_assignment" do
    let(:assignment) { double("Assignment") }

    before do
      allow(assignments_relation).to receive(:create).and_return(assignment)
    end

    it "creates a failed assignment with success: false" do
      expect(assignments_relation).to receive(:create).with(
        role: role,
        assignment_attempt: attempt,
        score: 0,
        reasoning: "No candidates available",
        tokens_used: 0,
        duration_ms: 0,
        ai_response: nil,
        success: false
      )

      described_class.create_failed_assignment(
        game: game,
        role: role,
        attempt: attempt,
        reasoning: "No candidates available"
      )
    end

    it "returns failure result" do
      result = described_class.create_failed_assignment(
        game: game,
        role: role,
        attempt: attempt,
        reasoning: "No candidates available"
      )

      expect(result[:success]).to be false
      expect(result[:assignment]).to eq(assignment)
      expect(result[:error]).to eq("No candidates available")
    end

    context "with optional parameters" do
      it "includes score when provided" do
        expect(assignments_relation).to receive(:create).with(
          hash_including(score: 45)
        )

        described_class.create_failed_assignment(
          game: game,
          role: role,
          attempt: attempt,
          reasoning: "Score too low",
          score: 45
        )
      end

      it "includes AI metadata when provided" do
        expect(assignments_relation).to receive(:create).with(
          hash_including(
            tokens_used: 100,
            duration_ms: 2000,
            ai_response: "AI text"
          )
        )

        described_class.create_failed_assignment(
          game: game,
          role: role,
          attempt: attempt,
          reasoning: "Failed",
          tokens_used: 100,
          duration_ms: 2000,
          ai_response: "AI text"
        )
      end
    end
  end

  describe ".build_assignment" do
    let(:assignment) { double("Assignment") }

    before do
      allow(assignments_relation).to receive(:build).and_return(assignment)
    end

    it "builds but does not save an assignment" do
      expect(assignments_relation).to receive(:build).with(
        official: official,
        role: role,
        assignment_attempt: attempt,
        score: 88,
        reasoning: "Decent match",
        tokens_used: 50,
        duration_ms: 3000,
        ai_response: "Response",
        success: true
      )

      result = described_class.build_assignment(
        game: game,
        official: official,
        role: role,
        attempt: attempt,
        score: 88,
        reasoning: "Decent match",
        tokens_used: 50,
        duration_ms: 3000,
        ai_response: "Response"
      )

      expect(result).to eq(assignment)
    end
  end

  describe ".save_assignment" do
    context "when assignment saves successfully" do
      let(:assignment) { double("Assignment", save: true) }

      it "returns success result" do
        result = described_class.save_assignment(assignment)

        expect(result[:success]).to be true
        expect(result[:assignment]).to eq(assignment)
      end
    end

    context "when assignment fails to save" do
      let(:assignment) do
        double("Assignment",
          save: false,
          errors: double(full_messages: ["Validation failed"])
        )
      end

      it "returns failure result with errors" do
        result = described_class.save_assignment(assignment)

        expect(result[:success]).to be false
        expect(result[:assignment]).to eq(assignment)
        expect(result[:errors]).to eq(["Validation failed"])
      end
    end
  end
end
