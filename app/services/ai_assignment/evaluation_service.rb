module AiAssignment
  class EvaluationService
    attr_reader :attempt

    def initialize(attempt)
      @attempt = attempt
      @violations = []
    end

    # Main evaluation method - creates AssignmentEvaluation with violations
    # Returns the created AssignmentEvaluation record
    def evaluate!
      Rails.logger.info "=" * 80
      Rails.logger.info "Starting validation for AssignmentAttempt ##{attempt.id}"
      Rails.logger.info "=" * 80

      # Create evaluation record
      evaluation = AssignmentEvaluation.create!(
        assignment_attempt: attempt,
        evaluated_at: Time.current
      )

      # Run rule-based checks (distance violations)
      check_distance_violations(evaluation)

      # Check for constraint violations (simultaneous games, role capability, etc.)
      check_constraint_violations(evaluation)

      # Calculate theoretical max comparison
      theoretical_comparison = calculate_theoretical_comparison

      # Update evaluation with results
      # Note: violation counts are auto-maintained by RuleViolation callbacks
      evaluation.update!(
        overall_score: nil,
        evaluation_reasoning: nil,
        theoretical_comparison: theoretical_comparison
      )

      Rails.logger.info "=" * 80
      Rails.logger.info "Validation complete for AssignmentAttempt ##{attempt.id}"
      Rails.logger.info "Total Violations: #{evaluation.total_violations}"
      Rails.logger.info "=" * 80

      evaluation
    rescue => e
      Rails.logger.error "Validation failed for AssignmentAttempt ##{attempt.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Try to update evaluation with error state
      evaluation&.update(
        overall_score: 0,
        evaluation_reasoning: "Validation failed: #{e.message}"
      )

      evaluation
    end

    private

    # Check for all types of constraint violations
    def check_constraint_violations(evaluation)
      successful_assignments = attempt.assignments.where(success: true).includes(:official, :game)

      successful_assignments.each do |assignment|
        check_assignment_constraints(assignment, evaluation)
      end
    end

    # Check if a single assignment violates any constraints
    def check_assignment_constraints(assignment, evaluation)
      official = assignment.official
      game = assignment.game

      # Check role capability
      unless official.can_fill_role?(assignment.role)
        create_constraint_violation(
          assignment, evaluation, :role_capability,
          "Official #{official.name} cannot fill #{assignment.role} role",
          :critical
        )
      end

      # Check availability
      unless official.available_for_game?(game)
        create_constraint_violation(
          assignment, evaluation, :availability,
          "Official #{official.name} is not available on #{game.game_date.strftime('%m/%d/%Y')}",
          :critical
        )
      end

      # Check for simultaneous game conflicts
      simultaneous_assignments = attempt.assignments.where(success: true)
        .where(official_id: official.id)
        .joins(:game)
        .where.not(id: assignment.id)
        .where(games: { game_date: game.game_date })

      if simultaneous_assignments.any?
        simultaneous_game = simultaneous_assignments.first.game
        create_constraint_violation(
          assignment, evaluation, :simultaneous_games,
          "Official #{official.name} assigned to multiple games at #{game.game_date.strftime('%m/%d/%Y %I:%M %p')} (#{game.name} and #{simultaneous_game.name})",
          :critical
        )
      end

      # Check for double-booking (same official, same game, multiple roles)
      duplicate_assignments = attempt.assignments.where(success: true)
        .where(official_id: official.id, game_id: game.id)
        .where.not(id: assignment.id)

      if duplicate_assignments.any?
        create_constraint_violation(
          assignment, evaluation, :double_booking,
          "Official #{official.name} assigned to #{game.name} multiple times (#{assignment.role} and #{duplicate_assignments.first.role})",
          :critical
        )
      end
    end

    # Create a constraint violation record
    def create_constraint_violation(assignment, evaluation, violation_type, description, severity)
      violation = RuleViolation.create!(
        assignment_evaluation: evaluation,
        assignment: assignment,
        official: assignment.official,
        rule: nil,
        violation_type: violation_type,
        severity: severity,
        description: description
      )

      @violations << violation

      Rails.logger.warn "Constraint violation (#{violation_type}): #{description}"
    end

    # Calculate comparison between AI assignments and theoretical maximum
    def calculate_theoretical_comparison
      return nil unless attempt.theoretical_max_fillable.present?

      constraint_violations = @violations.select do |v|
        [:role_capability, :availability, :simultaneous_games, :double_booking].include?(v.violation_type.to_sym)
      end

      {
        theoretical_max_fillable: attempt.theoretical_max_fillable,
        ai_assignments_made: attempt.assignments_made,
        difference: attempt.assignments_made - attempt.theoretical_max_fillable,
        exceeded_theoretical_max: attempt.assignments_made > attempt.theoretical_max_fillable,
        efficiency_percentage: attempt.theoretical_max_fillable > 0 ?
          (attempt.assignments_made.to_f / attempt.theoretical_max_fillable * 100).round(2) : 0,
        constraint_violations_count: constraint_violations.count,
        constraint_violations: constraint_violations.map do |v|
          {
            type: v.violation_type,
            severity: v.severity,
            description: v.description,
            official: v.official.name,
            game: v.assignment.game.name
          }
        end
      }
    end

    # Check all successful assignments for distance violations
    def check_distance_violations(evaluation)
      successful_assignments = attempt.assignments.where(success: true).includes(:official, :game)

      successful_assignments.each do |assignment|
        check_assignment_distance(assignment, evaluation)
      end
    end

    # Check if a single assignment violates distance constraints
    def check_assignment_distance(assignment, evaluation)
      official = assignment.official
      game = assignment.game

      # Skip if official has no distance limit
      return if official.max_distance.nil?

      # Calculate actual distance
      distance = DistanceCalculationService.between_game_and_official(game, official)

      # Skip if distance can't be calculated (missing coordinates)
      return if distance.nil?

      # Check if distance exceeds limit
      if distance > official.max_distance
        create_distance_violation(assignment, evaluation, distance, official.max_distance)
      end
    end

    # Create a distance violation record
    def create_distance_violation(assignment, evaluation, actual_distance, max_distance)
      violation = RuleViolation.create!(
        assignment_evaluation: evaluation,
        assignment: assignment,
        official: assignment.official,
        rule: nil,
        violation_type: :distance,
        severity: determine_distance_severity(actual_distance, max_distance),
        description: "Distance #{actual_distance.round(1)} miles exceeds official's maximum travel distance of #{max_distance} miles (#{((actual_distance - max_distance) / max_distance * 100).round(1)}% over limit)"
      )

      @violations << violation

      Rails.logger.warn "Distance violation: #{assignment.official.name} assigned to #{assignment.game.name} " \
                        "(#{actual_distance.round(1)}mi > #{max_distance}mi)"
    end

    # Determine severity based on how much the distance exceeds the limit
    def determine_distance_severity(actual_distance, max_distance)
      overage_percent = ((actual_distance - max_distance) / max_distance * 100).round(1)

      case overage_percent
      when 0..10
        :minor # Up to 10% over
      when 10..25
        :major # 10-25% over
      else
        :critical # More than 25% over
      end
    end
  end
end
