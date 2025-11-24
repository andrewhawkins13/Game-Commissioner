module AiAssignment
  class ReportGeneratorService
    # Generate a detailed report for an assignment attempt
    # @param attempt [AssignmentAttempt] The assignment attempt
    # @param games [Array<Game>] Games that were processed
    # @return [String] Formatted report
    def self.generate_detailed_report(attempt, games)
      report = []

      # Header
      report << "=" * 80
      report << "AI ASSIGNMENT ATTEMPT REPORT"
      report << "=" * 80
      report << ""

      # Attempt metadata
      add_attempt_metadata(report, attempt)

      # Metrics section
      add_metrics_section(report, attempt)

      # Theoretical max comparison section
      add_theoretical_comparison_section(report, attempt)

      # Game details
      add_game_details(report, attempt, games)

      # Footer
      report << ""
      report << "=" * 80

      report.join("\n")
    end

    private

    def self.add_attempt_metadata(report, attempt)
      report << "Attempt ID: #{attempt.id}"
      report << "Model: #{attempt.ollama_model}"
      report << "Started: #{attempt.started_at}"
      report << "Completed: #{attempt.completed_at}"

      if attempt.completed_at && attempt.started_at
        duration_ms = ((attempt.completed_at - attempt.started_at) * 1000).round(0)
        report << "Duration: #{duration_ms}ms"
      end

      report << ""
    end

    def self.add_metrics_section(report, attempt)
      report << "-" * 80
      report << "METRICS"
      report << "-" * 80
      report << "Total Games: #{attempt.total_games || 0}"
      report << "Games Processed: #{attempt.games_processed || 0}"
      report << "Total Positions: #{attempt.total_positions || 0}"
      report << "Successful Assignments: #{attempt.assignments_made || 0}"
      report << "Failed Assignments: #{attempt.assignments_failed || 0}"

      if attempt.fill_rate
        report << "Fill Rate: #{attempt.fill_rate.round(1)}%"
      end

      if attempt.avg_score
        report << "Average Score: #{attempt.avg_score.round(1)}"
      end

      report << "Total Tokens Used: #{attempt.total_tokens || 0}"

      # Calculate duration if available
      if attempt.duration_seconds
        report << "Total Duration: #{attempt.duration_seconds}s"
      end

      report << ""
    end

    def self.add_theoretical_comparison_section(report, attempt)
      return unless attempt.theoretical_max_fillable.present?

      report << "-" * 80
      report << "THEORETICAL MAX COMPARISON"
      report << "-" * 80
      report << "Theoretical Max Fillable: #{attempt.theoretical_max_fillable} positions"
      report << "AI Assignments Made: #{attempt.assignments_made} positions"

      difference = attempt.assignments_made - attempt.theoretical_max_fillable
      if difference > 0
        report << "Difference: +#{difference} (EXCEEDED theoretical max)"
        report << ""
        report << "⚠️  WARNING: AI assigned MORE positions than theoretically possible!"
        report << "This indicates constraint violations (e.g., officials at multiple"
        report << "games simultaneously). Check the evaluation report for details."
      elsif difference == 0
        report << "Difference: 0 (PERFECT! Matched theoretical max)"
        report << ""
        report << "✅ AI achieved the theoretical maximum fillable positions!"
      else
        report << "Difference: #{difference} (under theoretical max by #{difference.abs})"
        efficiency_pct = (attempt.assignments_made.to_f / attempt.theoretical_max_fillable * 100).round(1)
        report << "Efficiency: #{efficiency_pct}%"
      end

      report << ""
    end

    def self.add_game_details(report, attempt, games)
      report << "-" * 80
      report << "GAME DETAILS"
      report << "-" * 80

      games.each do |game|
        add_game_section(report, attempt, game)
      end
    end

    def self.add_game_section(report, attempt, game)
      report << ""
      report << "Game: #{game.name}"
      report << "  Date: #{game.game_date}"
      report << "  Location: #{game.location}"

      game_assignments = attempt.assignments.where(game: game)

      if game_assignments.any?
        add_game_assignments(report, game_assignments)
      else
        report << "  No assignments made"
      end
    end

    def self.add_game_assignments(report, game_assignments)
      report << "  Assignments (#{game_assignments.count}):"

      game_assignments.each do |assignment|
        status = assignment.success ? "✓" : "✗"
        official_name = assignment.official&.name || "None"
        score = assignment.score ? "#{assignment.score}/100" : "N/A"

        report << "    #{status} #{assignment.role.upcase}: #{official_name} (Score: #{score})"

        if assignment.reasoning.present?
          report << "       Reasoning: #{assignment.reasoning}"
        end
      end
    end
  end
end
