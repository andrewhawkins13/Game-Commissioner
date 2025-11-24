class Game < ApplicationRecord
  has_many :assignments, dependent: :destroy
  has_many :officials, through: :assignments

  enum :status, { scheduled: 0, in_progress: 1, completed: 2, cancelled: 3 }, default: :scheduled

  validates :name, presence: true
  validates :game_date, presence: true
  validates :location, presence: true
  validates :address, presence: true

  scope :upcoming, -> { where("game_date >= ?", Time.current).order(:game_date) }
  scope :with_open_positions, -> {
    left_joins(:assignments)
      .group("games.id")
      .having("COUNT(assignments.id) < 5")
  }

  def open_positions
    assigned_roles = assignments.where(success: true).pluck(:role)
    Assignment.roles.keys.reject { |role| assigned_roles.include?(role) }
  end

  def full?
    assignments.where(success: true).count == 5
  end

  def distance_to(official)
    DistanceCalculationService.between_game_and_official(self, official)
  end

  # Analyze why each unfilled position remains unfilled
  # Returns detailed information about candidates and rejection reasons
  def unfilled_positions_with_reasons
    return { message: "All positions filled!" } if full?

    analysis = {
      game: name,
      game_date: game_date,
      location: location,
      unfilled_roles: []
    }

    open_positions.each do |role|
      role_analysis = {
        role: role,
        candidates: []
      }

      # Find all officials with this role capability
      potential_officials = Official
        .joins(:official_roles)
        .where(official_roles: { role: role })
        .includes(:rules, :assignments)

      if potential_officials.empty?
        role_analysis[:candidates] << {
          message: "No officials in system with #{role} capability"
        }
      else
        potential_officials.each do |official|
          candidate_info = {
            name: official.name,
            email: official.email,
            rejection_reasons: []
          }

          # Check if already assigned to this game
          if assignments.where(official: official).exists?
            assigned_role = assignments.find_by(official: official).role
            candidate_info[:rejection_reasons] << "Already assigned to this game as #{assigned_role}"
          end

          # Check distance constraints
          if latitude.present? && longitude.present? &&
             official.latitude.present? && official.longitude.present?
            distance = distance_to(official)

            if official.max_distance.present? && distance > official.max_distance
              candidate_info[:rejection_reasons] << "Distance #{distance.round(1)} miles exceeds max_distance of #{official.max_distance} miles"
            else
              candidate_info[:distance_info] = "#{distance.round(1)} miles (within limit)"
            end
          elsif official.max_distance.present?
            candidate_info[:rejection_reasons] << "Distance could not be calculated (missing coordinates)"
          end

          # Include active rules
          active_rules = official.rules.active
          if active_rules.any?
            candidate_info[:active_rules] = active_rules.map(&:rule_text)
          end

          # Check for failed assignment attempts for this game/role/official
          failed_attempt = assignments.where(official: official, role: role, success: false).last
          if failed_attempt
            candidate_info[:rejection_reasons] << "Previous assignment attempt failed: #{failed_attempt.reasoning}"
          end

          # If no rejection reasons, they might still be available
          if candidate_info[:rejection_reasons].empty?
            candidate_info[:status] = "Available - not yet assigned"
          end

          role_analysis[:candidates] << candidate_info
        end
      end

      analysis[:unfilled_roles] << role_analysis
    end

    analysis
  end

  # Format the unfilled positions analysis as a readable string
  def unfilled_positions_report
    analysis = unfilled_positions_with_reasons

    return analysis[:message] if analysis[:message]

    lines = []
    lines << "Unfilled Positions Report for #{analysis[:game]}"
    lines << "=" * 60
    lines << "Date: #{analysis[:game_date]}"
    lines << "Location: #{analysis[:location]}"
    lines << ""

    analysis[:unfilled_roles].each do |role_data|
      lines << "Role: #{role_data[:role].upcase}"
      lines << "-" * 40

      role_data[:candidates].each_with_index do |candidate, index|
        if candidate[:message]
          lines << "  #{candidate[:message]}"
        else
          lines << "  #{index + 1}. #{candidate[:name]} (#{candidate[:email]})"
          lines << "     Distance: #{candidate[:distance_info]}" if candidate[:distance_info]

          if candidate[:active_rules]&.any?
            lines << "     Active Rules:"
            candidate[:active_rules].each do |rule|
              lines << "       - #{rule}"
            end
          end

          if candidate[:rejection_reasons].any?
            lines << "     Rejection Reasons:"
            candidate[:rejection_reasons].each do |reason|
              lines << "       - #{reason}"
            end
          else
            lines << "     Status: #{candidate[:status]}"
          end
        end
        lines << ""
      end
      lines << ""
    end

    lines.join("\n")
  end
end
