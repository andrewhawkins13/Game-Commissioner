class AssignSingleGameJob < ApplicationJob
  queue_as :default

  def perform(game_id:, attempt_id:, model: nil, distance_matrix: {})
    Rails.logger.info "Starting single game assignment for game_id: #{game_id}, attempt_id: #{attempt_id}..."

    game = Game.find(game_id)
    attempt = AssignmentAttempt.find(attempt_id)

    # Gather all available officials
    all_officials = Official.includes(:official_roles, :rules, :assignments, :availabilities)

    # Filter officials using detailed filter (checks role capability, distance, availability, already assigned)
    filter_result = AiAssignment::EligibilityFilterService.filter_with_details(
      all_officials,
      game: game,
      open_positions: game.open_positions
    )

    eligible_officials = filter_result[:eligible].map { |entry| entry[:official] }
    ineligible_count = filter_result[:ineligible].count

    Rails.logger.info "Processing game: #{game.name} with #{eligible_officials.count} eligible officials (#{ineligible_count} ineligible)"

    # Log ineligible officials and reasons for debugging
    if ineligible_count > 0 && eligible_officials.count == 0
      Rails.logger.warn "No eligible officials found for #{game.name}. Reasons:"
      filter_result[:ineligible].first(5).each do |entry|
        Rails.logger.warn "  - #{entry[:official].name}: #{entry[:reason]}"
      end

      # Create failed assignments for all open positions so they show up in the UI
      error_reason = "No eligible officials found. Top rejection reasons: " +
                     filter_result[:ineligible].first(3).map { |e| "#{e[:official].name} (#{e[:reason]})" }.join("; ")

      game.open_positions.each do |role|
        AiAssignment::AssignmentBuilderService.create_failed_assignment(
          game: game,
          role: role,
          attempt: attempt,
          reasoning: error_reason,
          score: 0,
          tokens_used: 0,
          duration_ms: 0
        )
      end

      # Return early if no eligible officials
      return {
        game_id: game.id,
        game_name: game.name,
        assignments_made: 0,
        assignments_failed: game.open_positions.count,
        error: "No eligible officials found for #{game.open_positions.count} open position(s): #{game.open_positions.join(', ')}",
        prompt: nil,
        ai_response: nil,
        tokens_used: 0,
        prompt_tokens: 0,
        completion_tokens: 0,
        duration_ms: 0
      }
    end

    # Delegate assignment logic to the dedicated service
    service = AiAssignment::SingleGameAssignmentService.new(
      game: game,
      attempt: attempt,
      model: model
    )

    results = service.perform(
      officials: eligible_officials,
      distance_matrix: distance_matrix
    )

    Rails.logger.info "Completed game #{game.name}: #{results[:assignments_made]} assigned, #{results[:assignments_failed]} failed"

    # Return results for parent job to aggregate
    {
      game_id: game.id,
      game_name: game.name,
      assignments_made: results[:assignments_made],
      assignments_failed: results[:assignments_failed],
      error: results[:errors].present? ? results[:errors].map { |e| e[:error] }.join(", ") : nil,
      tokens_used: results[:tokens_used],
      prompt_tokens: results[:prompt_tokens],
      completion_tokens: results[:completion_tokens],
      duration_ms: results[:duration_ms],
      prompt: results[:prompt],
      ai_response: results[:ai_response]
    }
  rescue => e
    Rails.logger.error "Job failed for game #{game_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    {
      game_id: game_id,
      error: e.message,
      assignments_made: 0,
      assignments_failed: 0
    }
  end
end
