module AiAssignment
  class EligibilityFilterService
    # Filter officials to only those who can fill at least one open position
    # Reduces prompt size by 20-50% by excluding irrelevant officials
    # @param officials [Array<Official>] All available officials
    # @param open_positions [Array<String>] List of open position roles
    # @return [Array<Official>] Filtered list of eligible officials
    def self.filter_eligible_officials(officials, open_positions)
      officials.select do |official|
        open_positions.any? { |role| official.can_fill_role?(role) }
      end
    end

    # Pre-calculate distance matrix to avoid repeated calculations
    # Returns hash with "game_id_official_id" => distance_in_miles
    # @param games [Array<Game>] Games to calculate distances for
    # @param officials [Array<Official>] Officials to calculate distances for
    # @return [Hash<String, Float>] Distance matrix with keys like "1_10" => 25.5
    def self.build_distance_matrix(games, officials)
      matrix = {}
      games.each do |game|
        next unless game.latitude.present? && game.longitude.present?

        officials.each do |official|
          key = "#{game.id}_#{official.id}"
          matrix[key] = DistanceCalculationService.between_game_and_official(game, official)
        end
      end
      matrix
    end

    # Filter officials by multiple criteria
    # @param officials [Array<Official>] Officials to filter
    # @param game [Game] Game they would be assigned to
    # @param open_positions [Array<String>] Open positions for the game
    # @return [Hash] Filtered officials with metadata
    def self.filter_with_details(officials, game:, open_positions:)
      eligible = []
      ineligible = []

      officials.each do |official|
        # Check if can fill any open position
        can_fill_positions = open_positions.select { |role| official.can_fill_role?(role) }

        if can_fill_positions.empty?
          ineligible << {
            official: official,
            reason: "Cannot fill any open positions"
          }
          next
        end

        # Check distance requirements
        if game.latitude.present? && game.longitude.present?
          unless DistanceCalculationService.within_travel_distance?(game, official)
            distance = DistanceCalculationService.between_game_and_official(game, official)
            ineligible << {
              official: official,
              reason: "Distance (#{distance&.round(1)} miles) exceeds maximum",
              distance: distance
            }
            next
          end
        end

        # Check availability
        unless official.available_for_game?(game)
          ineligible << {
            official: official,
            reason: "Not available on #{game.game_date.strftime('%Y-%m-%d')}"
          }
          next
        end

        # Check if already assigned
        if game.assignments.where(official: official).exists?
          ineligible << {
            official: official,
            reason: "Already assigned to this game"
          }
          next
        end

        eligible << {
          official: official,
          can_fill_positions: can_fill_positions,
          distance: DistanceCalculationService.between_game_and_official(game, official)
        }
      end

      {
        eligible: eligible,
        ineligible: ineligible,
        summary: {
          total: officials.count,
          eligible_count: eligible.count,
          ineligible_count: ineligible.count
        }
      }
    end
  end
end
