module Ollama
  class PromptBuilderService
    # Build data structure for assigning all positions for a single game
    # @param game [Game] The game to assign officials to
    # @param officials [Array<Official>] Available officials
    # @param distance_matrix [Hash] Pre-calculated distances (optional)
    # @return [Hash] Data structure for prompt template
    def self.build_single_game_data(game:, officials:, distance_matrix: {})
      # Build open positions list
      open_positions = game.open_positions

      # Build assigned roles list
      assigned_roles = game.assignments.includes(:official).map do |a|
        "#{a.role.upcase}: #{a.official.name}"
      end.join(", ")

      # Build officials section with distances and details
      officials_data = officials.map do |official|
        build_official_data(official: official, game: game, distance_matrix: distance_matrix)
      end

      {
        game: game,
        open_positions: open_positions,
        assigned_roles: assigned_roles,
        officials: officials_data,
        officials_text: format_officials_text(officials_data)
      }
    end

    # Build detailed data for a single official
    # @param official [Official] The official
    # @param game [Game] The game being evaluated
    # @param distance_matrix [Hash] Pre-calculated distances (optional)
    # @return [Hash] Official data structure
    def self.build_official_data(official:, game:, distance_matrix: {})
      roles = official.official_roles.map { |r| r.role.upcase }.join(", ")
      rules = official.rules.active.map(&:rule_text).join("\n    - ")
      current_assignments = official.assignments.count

      # Get pre-calculated distance or calculate on the fly
      distance_key = "#{game.id}_#{official.id}"
      distance = distance_matrix[distance_key] || DistanceCalculationService.between_game_and_official(game, official)
      distance_text = distance ? "#{distance.round(1)} miles" : "Distance unknown"

      # Check availability for this game
      available_for_game = official.available_for_game?(game)
      availability_text = if official.availabilities.empty?
        "Always available (no specific windows defined)"
      elsif available_for_game
        "Available for this game date"
      else
        windows = official.availabilities.map { |a| "#{a.start_time.strftime('%m/%d')}-#{a.end_time.strftime('%m/%d')}" }.join(", ")
        "Not available on #{game.game_date.strftime('%m/%d/%Y')} (available: #{windows})"
      end

      {
        id: official.id,
        name: official.name,
        home_address: official.home_address || "Not specified",
        roles: roles,
        max_distance: official.max_distance || "No limit",
        current_assignments: current_assignments,
        distance: distance,
        distance_text: distance_text,
        rules: rules,
        has_rules: rules.present?,
        available_for_game: available_for_game,
        availability_text: availability_text
      }
    end

    private

    # Format officials data into text for prompt template
    # @param officials_data [Array<Hash>] Array of official data hashes
    # @return [String] Formatted text
    def self.format_officials_text(officials_data)
      officials_data.map do |data|
        <<~OFFICIAL_INFO
          OFFICIAL #{data[:id]}: #{data[:name]}
          Home Address: #{data[:home_address]}
          Available Roles: #{data[:roles]}
          Maximum Travel Distance: #{data[:max_distance]} miles
          Current Assignments: #{data[:current_assignments]} games
          Distance to Game: #{data[:distance_text]}
          Availability: #{data[:availability_text]}
          Rules and Preferences:
          #{data[:has_rules] ? "    - #{data[:rules]}" : "    None specified"}
        OFFICIAL_INFO
      end.join("\n")
    end
  end
end
