module Ollama
  class ResponseParserService
    def initialize(model:)
      @model = model
    end

    # Parse an evaluation response (single official/role evaluation)
    # @param response [String] The AI response text
    # @return [Hash] Parsed response with :score, :reasoning, :error keys
    def parse_evaluation(response)
      # Try JSON first
      begin
        # Check if response needed markdown cleanup
        had_markdown = response.include?("```")
        clean_response = response.gsub(/```json\s*|\s*```/, "").strip

        if had_markdown
          Rails.logger.warn "[Format Compliance] Response contained markdown code blocks (model: #{@model})"
        end

        # Try to extract JSON if it's embedded in other text
        json_match = clean_response.match(/\{[\s\S]*"score"[\s\S]*\}/)
        json_string = json_match ? json_match[0] : clean_response
        had_extra_text = json_match && json_match[0] != clean_response

        if had_extra_text
          Rails.logger.warn "[Format Compliance] Response had extra text around JSON (model: #{@model})"
        end

        parsed = JSON.parse(json_string)

        if parsed["score"]
          Rails.logger.info "[Format Compliance] Successfully parsed JSON response (model: #{@model})"
          return {
            score: parsed["score"].to_i.clamp(0, 100),
            reasoning: parsed["reasoning"].to_s.strip,
            error: false
          }
        end
      rescue JSON::ParserError => e
        Rails.logger.error "[Format Compliance] JSON parse failed, using regex fallback (model: #{@model}): #{e.message}"
        # Fall through to regex parsing
      end

      # Fallback: Extract SCORE and REASONING from text format
      score_match = response.match(/SCORE:\s*(\d+)/)
      reasoning_match = response.match(/REASONING:\s*(.+?)(?:\n\n|\z)/m)

      score = score_match ? score_match[1].to_i : 0
      reasoning = reasoning_match ? reasoning_match[1].strip : response.strip

      {
        score: score.clamp(0, 100),
        reasoning: reasoning,
        error: false
      }
    end

    # Parse an assignment response (multiple assignments for game(s))
    # @param response [String] The AI response text
    # @param games [Array<Game>] Available games to match against
    # @param officials [Array<Official>] Available officials to match against
    # @return [Array<Hash>] Array of parsed assignments
    def parse_assignment(response, games:, officials:)
      assignments = []
      failed_parses = []

      # First, try to parse as JSON
      begin
        # Check if response needed markdown cleanup
        had_markdown = response.include?("```")
        clean_response = response.gsub(/```json\s*|\s*```/, "").strip

        if had_markdown
          Rails.logger.warn "[Format Compliance] Response contained markdown code blocks (model: #{@model})"
        end

        # Try to extract JSON if it's embedded in other text
        json_match = clean_response.match(/\{[\s\S]*"assignments"[\s\S]*\}/)
        json_string = json_match ? json_match[0] : clean_response
        had_extra_text = json_match && json_match[0] != clean_response

        if had_extra_text
          Rails.logger.warn "[Format Compliance] Response had extra text around JSON (model: #{@model})"
        end

        parsed = JSON.parse(json_string)

        if parsed["assignments"].is_a?(Array)
          parsed["assignments"].each do |assignment_data|
            game_id = assignment_data["game_id"]
            official_id = assignment_data["official_id"]
            role = assignment_data["role"]
            score = assignment_data["score"]
            reasoning = assignment_data["reasoning"]

            game = games.find { |g| g.id == game_id.to_i }
            official = officials.find { |o| o.id == official_id.to_i }

            if game && official
              assignments << {
                game: game,
                official: official,
                role: role.downcase,
                score: score.to_i.clamp(0, 100),
                reasoning: reasoning.to_s.strip
              }
            else
              # Track failed parse with details
              error_msg = []
              error_msg << "game not found (ID: #{game_id})" unless game
              error_msg << "official not found (ID: #{official_id})" unless official

              failed_parses << {
                game_id: game_id,
                official_id: official_id,
                role: role,
                score: score,
                reasoning: reasoning,
                error: error_msg.join(", ")
              }

              Rails.logger.warn "[Assignment Parse Failed] Game ID #{game_id}, Official ID #{official_id}, Role #{role}: #{error_msg.join(', ')}"
              Rails.logger.warn "  Available game IDs: #{games.map(&:id).join(', ')}"
              Rails.logger.warn "  Available official IDs: #{officials.map(&:id).join(', ')}"
            end
          end

          Rails.logger.info "[Format Compliance] Successfully parsed #{assignments.count} assignments from JSON (model: #{@model})"
          Rails.logger.warn "[Format Compliance] Failed to parse #{failed_parses.count} assignments (ID mismatches)" if failed_parses.any?
          return assignments
        end
      rescue JSON::ParserError => e
        Rails.logger.error "[Format Compliance] JSON parse failed, using regex fallback (model: #{@model}): #{e.message}"
      end

      # Fallback: Try old text-based format
      assignment_pattern = /ASSIGNMENT:\s*game_(\d+)\s*-\s*(\w+)\s*-\s*official_(\d+)\s*\nSCORE:\s*(\d+)\s*\nREASONING:\s*(.+?)(?=\n\n|ASSIGNMENT:|SUMMARY:|$)/m

      response.scan(assignment_pattern) do |match|
        game_id, role, official_id, score, reasoning = match

        game = games.find { |g| g.id == game_id.to_i }
        official = officials.find { |o| o.id == official_id.to_i }

        if game && official
          assignments << {
            game: game,
            official: official,
            role: role.downcase,
            score: score.to_i.clamp(0, 100),
            reasoning: reasoning.strip
          }
        else
          error_msg = []
          error_msg << "game not found (ID: #{game_id})" unless game
          error_msg << "official not found (ID: #{official_id})" unless official

          failed_parses << {
            game_id: game_id,
            official_id: official_id,
            role: role,
            score: score,
            reasoning: reasoning,
            error: error_msg.join(", ")
          }

          Rails.logger.warn "[Assignment Parse Failed] Game ID #{game_id}, Official ID #{official_id}, Role #{role}: #{error_msg.join(', ')}"
        end
      end

      Rails.logger.info "Parsed #{assignments.count} assignments using regex fallback"
      Rails.logger.warn "Failed to parse #{failed_parses.count} assignments (ID mismatches)" if failed_parses.any?
      assignments
    end
  end
end
