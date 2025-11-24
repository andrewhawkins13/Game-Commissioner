module AiAssignment
  class SingleGameAssignmentService
    def initialize(game:, attempt:, model: OllamaService::DEFAULT_MODEL)
      @game = game
      @attempt = attempt
      @model = model
      @client = Ollama::ClientService.new(model: @model)
      @parser = Ollama::ResponseParserService.new(model: @model)
    end

    def perform(officials:, distance_matrix: {})
      prompt = build_prompt(officials, distance_matrix)
      
      # Log prompt
      log_prompt(prompt, officials.count)

      start_time = Time.now
      response_data = @client.generate(prompt, num_predict: 1500, schema: Ollama::SchemaDefinitions::ASSIGNMENT_SCHEMA)
      duration_ms = ((Time.now - start_time) * 1000).round

      # Log response
      log_response(response_data, duration_ms, prompt.length)

      # Parse assignments
      assignments_data = @parser.parse_assignment(response_data["response"], games: [@game], officials: officials)

      # Process results
      process_results(assignments_data, response_data, duration_ms, prompt)
    end

    private

    def build_prompt(officials, distance_matrix)
      data = Ollama::PromptBuilderService.build_single_game_data(
        game: @game,
        officials: officials,
        distance_matrix: distance_matrix
      )
      Ollama::PromptRendererService.render_game_positions(data)
    end

    def process_results(assignments_data, response_data, duration_ms, prompt)
      prompt_tokens = response_data["prompt_eval_count"] || 0
      completion_tokens = response_data["eval_count"] || 0
      total_tokens = prompt_tokens + completion_tokens

      # Capture which roles we need to fill before we start creating assignments
      roles_to_fill = @game.open_positions
      attempted_roles = assignments_data.map { |data| data[:role] }

      results = {
        assignments_made: 0,
        assignments_failed: 0,
        errors: [],
        tokens_used: total_tokens,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        duration_ms: duration_ms,
        prompt: prompt,
        ai_response: response_data["response"]
      }

      # Calculate duration per assignment for tracking
      per_assignment_duration = duration_ms / (assignments_data.count.nonzero? || 1)

      assignments_data.each do |data|
        result = AssignmentBuilderService.create_assignment(
          game: @game,
          official: data[:official],
          role: data[:role],
          attempt: @attempt,
          score: data[:score],
          reasoning: data[:reasoning],
          tokens_used: total_tokens, # Full cost associated with this batch
          duration_ms: per_assignment_duration,
          ai_response: response_data["response"]
        )

        if result[:success]
          results[:assignments_made] += 1
          Rails.logger.info "✓ Assigned #{data[:official].name} to #{@game.name} as #{data[:role].upcase}"
        else
          results[:assignments_failed] += 1
          error_msg = result[:errors].join(", ")
          results[:errors] << { game: @game.name, role: data[:role], official: data[:official].name, error: error_msg }
          Rails.logger.error "✗ Failed to assign #{data[:official].name} to #{@game.name} as #{data[:role].upcase}: #{error_msg}"
        end
      end

      # Handle skipped roles (positions the AI ignored)
      missed_roles = roles_to_fill - attempted_roles
      missed_roles.each do |role|
        results[:assignments_failed] += 1
        AiAssignment::AssignmentBuilderService.create_failed_assignment(
          game: @game,
          role: role,
          attempt: @attempt,
          reasoning: "AI did not provide an assignment for this position",
          score: 0,
          tokens_used: total_tokens,
          duration_ms: per_assignment_duration,
          ai_response: response_data["response"]
        )
        Rails.logger.warn "✗ AI skipped assignment for #{@game.name} - #{role.upcase}"
      end

      results
    rescue => e
      Rails.logger.error "Assignment processing error: #{e.message}"
      results[:errors] << { error: e.message }
      results
    end

    def log_prompt(prompt, officials_count)
      Rails.logger.info "=" * 80
      Rails.logger.info "AI Assignment Prompt (#{@model})"
      Rails.logger.info "Game: #{@game.name}, Officials: #{officials_count}, Length: #{prompt.length}"
      Rails.logger.info "=" * 80
      Rails.logger.info prompt
      Rails.logger.info "=" * 80
    end

    def log_response(response_data, duration_ms, prompt_length)
      tokens = (response_data["prompt_eval_count"] || 0) + (response_data["eval_count"] || 0)
      Rails.logger.info "=" * 80
      Rails.logger.info "AI Response (#{@model})"
      Rails.logger.info "Duration: #{duration_ms}ms, Tokens: #{tokens}"
      Rails.logger.info "=" * 80
      Rails.logger.info response_data["response"]
      Rails.logger.info "=" * 80
    end

  end
end

