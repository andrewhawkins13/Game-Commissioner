class AssignOpenGamesJob < ApplicationJob
  queue_as :default

  def perform(model: nil)
    Rails.logger.info "Starting AI Assignment job with model: #{model || 'default'}..."

    begin
      results = perform_parallel_assignment(model: model)
      Rails.logger.info "AI Assignment completed: #{results.inspect}"
    rescue => e
      Rails.logger.error "AI Assignment job failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

  def perform_parallel_assignment(model:)
    # Create AssignmentAttempt to track this run
    attempt = AssignmentAttempt.create!(
      ollama_model: model || OllamaService::DEFAULT_MODEL,
      started_at: Time.current,
      status: :processing
    )

    results = {
      total_games: 0,
      assignments_made: 0,
      assignments_failed: 0,
      errors: [],
      attempt: attempt,
      total_prompt_tokens: 0,
      total_completion_tokens: 0
    }

    # Gather all games with open positions
    games = Game.upcoming.includes(:assignments, :officials)
    games_with_openings = games.select { |g| !g.full? }

    # Calculate total positions
    total_positions = games_with_openings.sum { |g| g.open_positions.count }
    attempt.update!(
      total_positions: total_positions,
      total_games: games_with_openings.count,
      games_processed: 0
    )

    if games_with_openings.empty?
      attempt.update!(completed_at: Time.current, status: :completed)
      return results
    end

    # Pre-calculate distance matrix once for all games
    all_officials = Official.includes(:official_roles, :rules, :assignments)
    distance_matrix = AiAssignment::EligibilityFilterService.build_distance_matrix(games_with_openings, all_officials)

    # Run theoretical max analysis BEFORE AI assignment
    Rails.logger.info "Running theoretical maximum analysis..."
    theoretical_max_service = Analysis::TheoreticalMaxAnalysisService.new
    theoretical_max_report = theoretical_max_service.perform

    # Save theoretical max results
    attempt.update!(
      theoretical_max_report: theoretical_max_report,
      theoretical_max_fillable: theoretical_max_service.theoretical_max
    )

    Rails.logger.info "Theoretical max: #{theoretical_max_service.theoretical_max}/#{total_positions} positions"
    Rails.logger.info "Launching #{games_with_openings.count} parallel game assignment jobs..."

    # Launch parallel jobs for each game
    game_jobs = games_with_openings.map do |game|
      AssignSingleGameJob.perform_now(
        game_id: game.id,
        attempt_id: attempt.id,
        model: model,
        distance_matrix: distance_matrix
      )
    end

    # Aggregate results from all jobs
    all_prompts = []
    all_responses = []

    game_jobs.each do |job_result|
      results[:total_games] += 1
      results[:assignments_made] += job_result[:assignments_made]
      results[:assignments_failed] += job_result[:assignments_failed]

      # Aggregate token usage
      results[:total_prompt_tokens] += job_result[:prompt_tokens] || 0
      results[:total_completion_tokens] += job_result[:completion_tokens] || 0

      # Track errors
      if job_result[:error]
        results[:errors] << {
          game_id: job_result[:game_id],
          game_name: job_result[:game_name],
          error: job_result[:error]
        }
      elsif job_result[:errors]
        results[:errors].concat(job_result[:errors])
      end

      # Collect prompts and responses
      if job_result[:prompt]
        game_name = job_result[:game_name] || "Game #{job_result[:game_id]}"
        all_prompts << "=== Game: #{game_name} ===\n#{job_result[:prompt]}"
      end
      if job_result[:ai_response]
        game_name = job_result[:game_name] || "Game #{job_result[:game_id]}"
        all_responses << "=== Game: #{game_name} ===\n#{job_result[:ai_response]}"
      end
    end

    # Determine final status based on results
    # Only fail if there are actual LLM errors (errors from the AI service itself)
    # Validation errors (official can't fill role, etc.) don't count as failures
    has_llm_errors = results[:errors].any? { |e| e[:error].to_s.include?("AI Error:") || e[:error].to_s.include?("Ollama") }
    final_status = has_llm_errors ? :failed : :completed

    # Only store error messages for actual failures (LLM/AI errors)
    # Validation errors (can't fill role, already assigned) are normal and tracked in metrics
    error_message = if has_llm_errors
      results[:errors].select { |e| e[:error].to_s.include?("AI Error:") || e[:error].to_s.include?("Ollama") }
                     .map { |e| "#{e[:game_name] || e[:game_id]}: #{e[:error]}" }
                     .join("\n")
    end

    # Finalize the attempt (but keep status as processing until evaluation is done)
    attempt.update!(
      completed_at: Time.current,
      # status: final_status, # Delayed until after evaluation
      error_message: error_message
    )

    # Calculate and store metrics
    attempt.calculate_metrics!(
      prompt_tokens: results[:total_prompt_tokens],
      completion_tokens: results[:total_completion_tokens]
    )

    # Generate detailed report
    detailed_report = AiAssignment::ReportGeneratorService.generate_detailed_report(attempt, games_with_openings)
    Rails.logger.info "\n#{detailed_report}"

    # Store detailed log and aggregated prompts/responses
    attempt.update!(
      detailed_log: detailed_report,
      prompt: all_prompts.join("\n\n"),
      ai_response: all_responses.join("\n\n")
    )

    # Trigger automatic evaluation
    trigger_evaluation(attempt, model)

    # Finally update status to stop polling
    attempt.update!(status: final_status)

    results
  rescue => e
    attempt&.update(status: :failed, completed_at: Time.current)
    raise
  end

  def build_result_message(results)
    if results[:assignments_made] > 0
      msg = "AI Assignment completed! #{results[:assignments_made]} assignments made"
      msg += ", #{results[:assignments_failed]} failed" if results[:assignments_failed] > 0
      msg += " across #{results[:total_games]} games with open positions."
    else
      "No assignments made. #{results[:assignments_failed]} positions could not be filled."
    end
  end

  def trigger_evaluation(attempt, model)
    Rails.logger.info "Triggering automatic evaluation for AssignmentAttempt ##{attempt.id}"

    begin
      evaluation_service = AiAssignment::EvaluationService.new(attempt)
      evaluation = evaluation_service.evaluate!

      Rails.logger.info "Evaluation completed: Score #{evaluation.overall_score} (Grade: #{evaluation.grade})"
    rescue => e
      Rails.logger.error "Evaluation failed for AssignmentAttempt ##{attempt.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Don't fail the entire assignment if evaluation fails
    end
  end
end
