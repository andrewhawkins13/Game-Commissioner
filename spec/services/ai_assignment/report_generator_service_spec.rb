require "rails_helper"

RSpec.describe AiAssignment::ReportGeneratorService do
  describe ".generate_detailed_report" do
    let(:started_at) { Time.zone.parse("2025-01-15 10:00:00") }
    let(:completed_at) { Time.zone.parse("2025-01-15 10:05:30") }

    let(:attempt) do
      double("AssignmentAttempt",
        id: 123,
        ollama_model: "llama3.2",
        started_at: started_at,
        completed_at: completed_at,
        total_games: 5,
        games_processed: 5,
        total_positions: 25,
        assignments_made: 20,
        assignments_failed: 5,
        success_rate: 80.0,
        avg_score: 85.5,
        total_tokens: 15000,
        total_duration_ms: 330000,
        fill_rate: 80.0,
        duration_seconds: 330,
        theoretical_max_fillable: nil
      )
    end

    let(:game1) do
      double("Game",
        id: 1,
        name: "Game 1",
        game_date: Time.zone.parse("2025-01-20 14:00"),
        location: "Stadium A"
      )
    end

    let(:game2) do
      double("Game",
        id: 2,
        name: "Game 2",
        game_date: Time.zone.parse("2025-01-21 15:00"),
        location: "Stadium B"
      )
    end

    let(:games) { [game1, game2] }

    let(:official1) { double("Official", name: "John Doe") }
    let(:official2) { double("Official", name: "Jane Smith") }

    let(:assignment1) do
      double("Assignment",
        success: true,
        official: official1,
        role: "referee",
        score: 90,
        reasoning: "Excellent match"
      )
    end

    let(:assignment2) do
      double("Assignment",
        success: true,
        official: official2,
        role: "umpire",
        score: 85,
        reasoning: "Good fit"
      )
    end

    let(:assignment3) do
      double("Assignment",
        success: false,
        official: nil,
        role: "linesman",
        score: 0,
        reasoning: "No suitable official found"
      )
    end

    before do
      # Mock game 1 assignments
      game1_assignments = [assignment1, assignment2]
      allow(attempt).to receive(:assignments).and_return(double("AssignmentsRelation"))
      allow(attempt.assignments).to receive(:where).with(game: game1).and_return(game1_assignments)

      # Mock game 2 assignments
      game2_assignments = [assignment3]
      allow(attempt.assignments).to receive(:where).with(game: game2).and_return(game2_assignments)
    end

    it "generates a complete report" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to be_a(String)
      expect(report).to include("AI ASSIGNMENT ATTEMPT REPORT")
    end

    it "includes attempt metadata" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to include("Attempt ID: 123")
      expect(report).to include("Model: llama3.2")
      expect(report).to include("Started: #{started_at}")
      expect(report).to include("Completed: #{completed_at}")
      expect(report).to include("Duration: 330000ms")
    end

    it "includes metrics section" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to include("METRICS")
      expect(report).to include("Total Games: 5")
      expect(report).to include("Games Processed: 5")
      expect(report).to include("Total Positions: 25")
      expect(report).to include("Successful Assignments: 20")
      expect(report).to include("Failed Assignments: 5")
      expect(report).to include("Fill Rate: 80.0%")
      expect(report).to include("Average Score: 85.5")
      expect(report).to include("Total Tokens Used: 15000")
      expect(report).to include("Total Duration: 330s")
    end

    it "includes game details" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to include("GAME DETAILS")
      expect(report).to include("Game: Game 1")
      expect(report).to include("Game: Game 2")
      expect(report).to include("Location: Stadium A")
      expect(report).to include("Location: Stadium B")
    end

    it "includes successful assignment details" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to include("✓ REFEREE: John Doe (Score: 90/100)")
      expect(report).to include("Reasoning: Excellent match")
      expect(report).to include("✓ UMPIRE: Jane Smith (Score: 85/100)")
      expect(report).to include("Reasoning: Good fit")
    end

    it "includes failed assignment details" do
      report = described_class.generate_detailed_report(attempt, games)

      expect(report).to include("✗ LINESMAN: None (Score: 0/100)")
      expect(report).to include("Reasoning: No suitable official found")
    end

    context "when attempt has no completed_at" do
      let(:attempt_incomplete) do
        double("AssignmentAttempt",
          id: 124,
          ollama_model: "llama3.2",
          started_at: started_at,
          completed_at: nil,
          total_games: 0,
          games_processed: 0,
          total_positions: 0,
          assignments_made: 0,
          assignments_failed: 0,
          success_rate: nil,
          avg_score: nil,
          total_tokens: 0,
          total_duration_ms: 0,
          fill_rate: nil,
          duration_seconds: nil,
          theoretical_max_fillable: nil
        )
      end

      before do
        allow(attempt_incomplete).to receive(:assignments).and_return(double("AssignmentsRelation"))
        allow(attempt_incomplete.assignments).to receive(:where).with(game: game1).and_return([])
        allow(attempt_incomplete.assignments).to receive(:where).with(game: game2).and_return([])
      end

      it "handles incomplete attempt gracefully" do
        report = described_class.generate_detailed_report(attempt_incomplete, games)

        expect(report).to include("Attempt ID: 124")
        expect(report).to include("Total Games: 0")
        expect(report).to include("GAME DETAILS")
        # Success rate and avg score not shown when nil
        expect(report).not_to include("Fill Rate:")
        expect(report).not_to include("Average Score:")
      end
    end

    context "when game has no assignments" do
      before do
        allow(attempt.assignments).to receive(:where).with(game: game1).and_return([])
      end

      it "shows no assignments message" do
        report = described_class.generate_detailed_report(attempt, [game1])

        expect(report).to include("Game: Game 1")
        expect(report).to include("No assignments made")
      end
    end

    context "when assignment has no reasoning" do
      let(:assignment_no_reason) do
        double("Assignment",
          success: true,
          official: official1,
          role: "referee",
          score: 90,
          reasoning: nil
        )
      end

      before do
        allow(attempt.assignments).to receive(:where).with(game: game1).and_return([assignment_no_reason])
      end

      it "does not include reasoning line" do
        report = described_class.generate_detailed_report(attempt, [game1])

        expect(report).to include("✓ REFEREE: John Doe (Score: 90/100)")
        expect(report).not_to include("Reasoning:")
      end
    end

    context "when assignment has no score" do
      let(:assignment_no_score) do
        double("Assignment",
          success: false,
          official: nil,
          role: "referee",
          score: nil,
          reasoning: "Failed"
        )
      end

      before do
        allow(attempt.assignments).to receive(:where).with(game: game1).and_return([assignment_no_score])
      end

      it "shows N/A for score" do
        report = described_class.generate_detailed_report(attempt, [game1])

        expect(report).to include("✗ REFEREE: None (Score: N/A)")
      end
    end
  end
end
