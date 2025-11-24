class AssignmentAttempt < ApplicationRecord
  has_many :assignments, dependent: :destroy
  has_one :assignment_evaluation, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }, default: :pending

  validates :ollama_model, presence: true
  validate :completed_at_after_started_at

  scope :recent, -> { order(created_at: :desc) }
  scope :by_model, ->(model) { where(ollama_model: model) }
  scope :successful, -> { where(status: :completed) }

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).to_i
  end

  def assignments_made
    read_attribute(:assignments_made) || 0
  end

  def assignments_failed
    read_attribute(:assignments_failed) || 0
  end

  def fill_rate
    return 0 if total_positions.nil? || total_positions.zero?
    (assignments_made.to_f / total_positions * 100).round(2)
  end
  alias_method :success_rate, :fill_rate

  def games_processed
    @games_processed ||= assignments.select(:game_id).distinct.count
  end

  def prompt_tokens_total
    read_attribute(:prompt_tokens_total) || 0
  end

  def completion_tokens_total
    read_attribute(:completion_tokens_total) || 0
  end

  def successful_assignment_tokens
    @successful_assignment_tokens ||= calculate_unique_token_usage[:successful_tokens]
  end

  def calculate_metrics!(prompt_tokens: nil, completion_tokens: nil)
    # Calculate assignment metrics from the association
    made = assignments.where(success: true).count
    failed = assignments.where(success: false).count

    # Calculate token metrics, accounting for batch calls
    # For batch calls, multiple assignments share the same LLM call and token cost
    # We identify unique LLM calls by grouping assignments with the same ai_response
    token_data = calculate_unique_token_usage

    # Update all metrics in the database
    update_columns(
      assignments_made: made,
      assignments_failed: failed,
      total_tokens: token_data[:total_tokens],
      prompt_tokens_total: prompt_tokens || 0,
      completion_tokens_total: completion_tokens || 0
    )

    # Cache the token data for the new methods to use
    @successful_assignment_tokens = token_data[:successful_tokens]
  end

  def avg_score
    scores = assignments.where(success: true).where.not(score: nil).pluck(:score)
    return 0 if scores.empty?
    (scores.sum.to_f / scores.count).round(2)
  end

  def evaluated?
    assignment_evaluation.present?
  end

  def evaluation_summary
    return "Not evaluated" unless evaluated?

    eval = assignment_evaluation
    "Violations: #{eval.rule_violations_count}"
  end

  # Convenience methods for displaying attempt data

  def games
    Game.joins(:assignments).where(assignments: { assignment_attempt_id: id }).distinct
  end

  def officials
    Official.joins(:assignments).where(assignments: { assignment_attempt_id: id }).distinct
  end

  def successful_assignments
    assignments.where(success: true).includes(:game, :official)
  end

  def failed_assignments
    assignments.where(success: false).includes(:game, :official)
  end

  def assignments_by_game
    assignments.includes(:game, :official).group_by(&:game)
  end

  def assignments_by_official
    assignments.includes(:game, :official).group_by(&:official)
  end

  # Return the detailed assignment report
  # Generates a summary of the attempt on-the-fly
  def detailed_summary
    lines = []
    lines << "Assignment Attempt ##{id}"
    lines << "Model: #{ollama_model}"
    lines << "Status: #{status}"
    lines << "Total Positions: #{total_positions || 0}"
    lines << "Assignments Made: #{assignments_made || 0}"
    lines << "Assignments Failed: #{assignments_failed || 0}"
    lines << "Fill Rate: #{fill_rate || 0}%"
    lines << ""
    lines << "Successful Assignments:"
    successful_assignments.each do |a|
      lines << "  - #{a.game.name} (#{a.role}): #{a.official.name}"
    end
    lines << ""
    lines << "Failed Assignments:"
    failed_assignments.each do |a|
      lines << "  - #{a.game.name} (#{a.role}): #{a.reasoning || 'No reason provided'}"
    end
    lines.join("\n")
  end

  # Generate a report of unfilled positions from this attempt
  # This analyzes games that were processed but still have openings
  def unfilled_positions_report
    lines = []
    lines << "Unfilled Positions Report for Attempt ##{id}"
    lines << "=" * 60
    lines << ""

    # Get all games from this attempt
    attempt_games = games.includes(:assignments)

    games_with_openings = attempt_games.select { |g| !g.full? }

    if games_with_openings.empty?
      lines << "All positions filled!"
    else
      games_with_openings.each do |game|
        lines << "Game: #{game.name}"
        lines << "Date: #{game.game_date}"
        lines << "Location: #{game.location}"
        lines << "Open Positions: #{game.open_positions.join(', ')}"

        # Show failed assignment attempts for this game from this attempt
        game_failures = failed_assignments.where(game: game)
        if game_failures.any?
          lines << "Failed Assignment Attempts:"
          game_failures.each do |failure|
            lines << "  - #{failure.role}: #{failure.reasoning}"
          end
        end

        lines << ""
      end
    end

    lines.join("\n")
  end

  private

  # Calculate unique token usage by identifying distinct LLM calls
  # For batch calls, multiple assignments share the same LLM call
  # We group by ai_response to identify unique calls
  def calculate_unique_token_usage
    # Group assignments by ai_response to identify unique LLM calls
    # Assignments with the same ai_response came from the same LLM call
    unique_calls = assignments
      .select("DISTINCT ON (ai_response) *")
      .where.not(ai_response: nil)
      .to_a

    # Also include assignments with null ai_response (edge cases)
    null_response_assignments = assignments.where(ai_response: nil).to_a

    all_unique = unique_calls + null_response_assignments

    # Calculate totals from unique calls
    total_tokens = all_unique.sum(&:tokens_used) || 0
    prompt_tokens_total = 0
    completion_tokens_total = 0

    # For successful assignment tokens, only count unique successful calls
    successful_unique_calls = assignments
      .where(success: true)
      .select("DISTINCT ON (ai_response) *")
      .where.not(ai_response: nil)
      .to_a

    successful_null = assignments
      .where(success: true, ai_response: nil)
      .to_a

    all_successful_unique = successful_unique_calls + successful_null
    successful_tokens = all_successful_unique.sum(&:tokens_used) || 0

    {
      total_tokens: total_tokens,
      prompt_tokens_total: prompt_tokens_total,
      completion_tokens_total: completion_tokens_total,
      successful_tokens: successful_tokens
    }
  end

  def completed_at_after_started_at
    return unless completed_at.present? && started_at.present?

    if completed_at < started_at
      errors.add(:completed_at, "must be after started_at")
    end
  end
end
