module AiAssignment
  class AssignmentBuilderService
    # Create a successful assignment record
    # @param game [Game] The game
    # @param official [Official] The official being assigned
    # @param role [String] The role
    # @param attempt [AssignmentAttempt] The assignment attempt
    # @param score [Integer] AI-generated score
    # @param reasoning [String] AI reasoning
    # @param tokens_used [Integer] Tokens used by AI
    # @param duration_ms [Integer] Duration in milliseconds
    # @param ai_response [String] Raw AI response
    # @return [Hash] Result with :success, :assignment, :errors keys
    def self.create_assignment(game:, official:, role:, attempt:, score:, reasoning:, tokens_used: 0, duration_ms: 0, ai_response: nil)
      assignment = game.assignments.create(
        official: official,
        role: role,
        assignment_attempt: attempt,
        score: score,
        reasoning: reasoning,
        tokens_used: tokens_used,
        duration_ms: duration_ms,
        ai_response: ai_response,
        success: true
      )

      if assignment.persisted?
        {
          success: true,
          assignment: assignment,
          score: score,
          reasoning: reasoning
        }
      else
        {
          success: false,
          assignment: assignment,
          errors: assignment.errors.full_messages
        }
      end
    end

    # Create a failed assignment record
    # @param game [Game] The game
    # @param role [String] The role
    # @param attempt [AssignmentAttempt] The assignment attempt
    # @param reasoning [String] Reason for failure
    # @param score [Integer] AI score if available (optional)
    # @param tokens_used [Integer] Tokens used by AI
    # @param duration_ms [Integer] Duration in milliseconds
    # @param ai_response [String] Raw AI response (optional)
    # @return [Hash] Result with :success false, :assignment, :error keys
    def self.create_failed_assignment(game:, role:, attempt:, reasoning:, score: 0, tokens_used: 0, duration_ms: 0, ai_response: nil)
      assignment = game.assignments.create(
        role: role,
        assignment_attempt: attempt,
        score: score,
        reasoning: reasoning,
        tokens_used: tokens_used,
        duration_ms: duration_ms,
        ai_response: ai_response,
        success: false
      )

      {
        success: false,
        assignment: assignment,
        error: reasoning
      }
    end

    # Build (but don't save) an assignment record
    # Useful when you want to validate before saving
    # @param game [Game] The game
    # @param official [Official] The official being assigned
    # @param role [String] The role
    # @param attempt [AssignmentAttempt] The assignment attempt
    # @param score [Integer] AI-generated score
    # @param reasoning [String] AI reasoning
    # @param tokens_used [Integer] Tokens used by AI
    # @param duration_ms [Integer] Duration in milliseconds
    # @param ai_response [String] Raw AI response
    # @return [Assignment] Unsaved assignment record
    def self.build_assignment(game:, official:, role:, attempt:, score:, reasoning:, tokens_used: 0, duration_ms: 0, ai_response: nil)
      game.assignments.build(
        official: official,
        role: role,
        assignment_attempt: attempt,
        score: score,
        reasoning: reasoning,
        tokens_used: tokens_used,
        duration_ms: duration_ms,
        ai_response: ai_response,
        success: true
      )
    end

    # Save an assignment and return result
    # @param assignment [Assignment] The assignment to save
    # @return [Hash] Result with :success, :assignment, :errors keys
    def self.save_assignment(assignment)
      if assignment.save
        {
          success: true,
          assignment: assignment
        }
      else
        {
          success: false,
          assignment: assignment,
          errors: assignment.errors.full_messages
        }
      end
    end
  end
end
