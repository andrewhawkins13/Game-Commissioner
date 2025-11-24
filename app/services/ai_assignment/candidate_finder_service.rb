module AiAssignment
  class CandidateFinderService
    # Find officials who can fill a specific role for a game
    # @param game [Game] The game needing officials
    # @param role [String] The role to fill (referee, umpire, etc.)
    # @return [Array<Official>] Array of eligible officials
    def self.find_candidates(game:, role:)
      # Find officials who:
      # 1. Can fill this role
      # 2. Are not already assigned to this game
      # 3. Meet distance requirements (if set)

      officials = Official
        .joins(:official_roles)
        .where(official_roles: { role: role })
        .where.not(id: game.assignments.pluck(:official_id))

      # Filter by distance if both game and official have coordinates
      if game.latitude.present? && game.longitude.present?
        officials = officials.select do |official|
          DistanceCalculationService.within_travel_distance?(game, official)
        end
      end

      officials
    end

    # Find all officials who can fill ANY of the given roles for a game
    # @param game [Game] The game needing officials
    # @param roles [Array<String>] Array of roles to check
    # @return [Array<Official>] Array of eligible officials (deduplicated)
    def self.find_candidates_for_roles(game:, roles:)
      return [] if roles.empty?

      # Get all officials who can fill at least one of the roles
      officials = Official
        .joins(:official_roles)
        .where(official_roles: { role: roles })
        .where.not(id: game.assignments.pluck(:official_id))
        .distinct

      # Filter by distance if both game and officials have coordinates
      if game.latitude.present? && game.longitude.present?
        officials = officials.select do |official|
          DistanceCalculationService.within_travel_distance?(game, official)
        end
      end

      officials
    end

    # Check if a specific official can be assigned to a game for a role
    # @param game [Game] The game
    # @param official [Official] The official to check
    # @param role [String] The role
    # @return [Hash] Result with :eligible boolean and :reason string
    def self.can_assign?(game:, official:, role:)
      # Check if official has the required role
      unless official.can_fill_role?(role)
        return {
          eligible: false,
          reason: "Official cannot fill role '#{role}'"
        }
      end

      # Check if already assigned to this game
      if game.assignments.where(official: official).exists?
        return {
          eligible: false,
          reason: "Official is already assigned to this game"
        }
      end

      # Check distance requirements
      if game.latitude.present? && game.longitude.present?
        unless DistanceCalculationService.within_travel_distance?(game, official)
          distance = DistanceCalculationService.between_game_and_official(game, official)
          return {
            eligible: false,
            reason: "Distance (#{distance&.round(1)} miles) exceeds official's maximum travel distance"
          }
        end
      end

      {
        eligible: true,
        reason: "Official meets all requirements"
      }
    end
  end
end
