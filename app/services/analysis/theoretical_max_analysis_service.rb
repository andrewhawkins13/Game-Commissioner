# frozen_string_literal: true

module Analysis
  class TheoreticalMaxAnalysisService
    attr_reader :games, :officials, :analysis_results, :theoretical_max

    def initialize
      @games = Game.order(:game_date).includes(:assignments)
      @officials = Official.includes(:official_roles, :rules, :availabilities)
      @analysis_results = {}
      @theoretical_max = 0
    end

    def perform
      analyze_all_positions
      calculate_theoretical_maximum
      generate_report
    end

    private

    def analyze_all_positions
      games.each do |game|
        @analysis_results[game.id] = {}

        Assignment::ROLES.each_key do |role|
          @analysis_results[game.id][role] = analyze_position(game, role)
        end
      end
    end

    def analyze_position(game, role)
      eligible_officials = []
      ineligible_officials = []

      officials.each do |official|
        eligibility = check_eligibility(official, game, role)

        if eligibility[:eligible]
          eligible_officials << {
            official: official,
            distance: eligibility[:distance],
            concerns: eligibility[:concerns]
          }
        else
          ineligible_officials << {
            official: official,
            reasons: eligibility[:reasons]
          }
        end
      end

      {
        game: game,
        role: role,
        eligible_count: eligible_officials.length,
        eligible_officials: eligible_officials.sort_by { |e| e[:distance] || Float::INFINITY },
        ineligible_officials: ineligible_officials
      }
    end

    def check_eligibility(official, game, role)
      reasons = []
      concerns = []
      distance = nil

      # Check role capability
      unless official.can_fill_role?(role)
        reasons << "Cannot fill #{role} role"
      end

      # Check if already assigned to this game
      if official.assignments.exists?(game_id: game.id, success: true)
        reasons << "Already assigned to this game"
      end

      # Check availability
      unless official.available_for_game?(game)
        reasons << "Not available on #{game.game_date.strftime('%m/%d/%Y')}"
      end

      # Check distance
      if game.latitude.present? && game.longitude.present? &&
         official.latitude.present? && official.longitude.present?
        distance = official.distance_to(game)

        unless official.within_travel_distance?(game)
          reasons << "Distance #{distance.round(1)} miles exceeds limit of #{official.max_distance} miles"
        end
      end

      # Check back-to-back games rule
      back_to_back_rule = official.rules.active.find { |r| r.rule_text.downcase.include?('back to back') || r.rule_text.downcase.include?('consecutive') }
      if back_to_back_rule
        game_date = game.game_date.to_date
        prev_day = game_date - 1.day
        next_day = game_date + 1.day

        has_prev = official.assigned_on_date?(prev_day)
        has_next = official.assigned_on_date?(next_day)

        if has_prev || has_next
          concerns << "Back-to-back game conflict (has game on #{has_prev ? prev_day : next_day})"
        end
      end

      # Check custom rules
      official.rules.active.each do |rule|
        rule_text = rule.rule_text.downcase

        # Check location-based rules
        if rule_text.include?('school') || rule_text.include?('location')
          location_keywords = rule_text.scan(/(?:at\s+)?(\w+(?:\s+\w+)*?\s+(?:high\s+school|school|stadium))/).flatten
          location_keywords.each do |keyword|
            if game.location.downcase.include?(keyword.downcase) ||
               (game.address && game.address.downcase.include?(keyword.downcase))
              concerns << "Custom rule: #{rule.rule_text}"
            end
          end
        end

        # Check distance-based custom rules
        if rule_text.include?('mile') && distance
          distance_match = rule_text.match(/(\d+)\s*mile/)
          if distance_match
            custom_max_distance = distance_match[1].to_i
            if distance > custom_max_distance
              concerns << "Custom distance rule: #{rule.rule_text} (actual: #{distance.round(1)} miles)"
            end
          end
        end
      end

      {
        eligible: reasons.empty?,
        reasons: reasons,
        concerns: concerns,
        distance: distance
      }
    end

    def calculate_theoretical_maximum
      # Use greedy algorithm to find a theoretical maximum
      # This is a simplified approach - doesn't guarantee absolute optimal but gives good estimate

      total_fillable = 0
      assignment_plan = []

      # Track which officials have been used (to avoid double-booking on same game)
      game_official_usage = Hash.new { |h, k| h[k] = Set.new }

      # Track which officials have been assigned at each datetime (for simultaneous games)
      datetime_official_usage = Hash.new { |h, k| h[k] = Set.new }

      # Process positions by difficulty (fewest eligible officials first)
      all_positions = []
      @analysis_results.each do |game_id, roles|
        roles.each do |role, data|
          all_positions << data
        end
      end

      # Sort by eligible count (hardest to fill first)
      all_positions.sort_by! { |pos| pos[:eligible_count] }

      all_positions.each do |position|
        game = position[:game]
        role = position[:role]
        game_datetime = game.game_date

        # Find an eligible official who hasn't been assigned to this game yet
        # and isn't assigned to another game at the same time
        assigned = false
        position[:eligible_officials].each do |eligible|
          official = eligible[:official]

          # Check if official is available (not assigned to this game or any simultaneous game)
          next if game_official_usage[game.id].include?(official.id)
          next if datetime_official_usage[game_datetime].include?(official.id)

          # Check back-to-back concerns for a more realistic assignment
          if eligible[:concerns].empty? || eligible[:concerns].none? { |c| c.include?('Back-to-back') }
            game_official_usage[game.id].add(official.id)
            datetime_official_usage[game_datetime].add(official.id)
            total_fillable += 1
            assignment_plan << {
              game: game,
              role: role,
              official: official,
              distance: eligible[:distance],
              concerns: eligible[:concerns]
            }
            assigned = true
            break
          end
        end

        # If we couldn't assign without concerns, try with concerns
        unless assigned
          position[:eligible_officials].each do |eligible|
            official = eligible[:official]

            # Check if official is available (not assigned to this game or any simultaneous game)
            next if game_official_usage[game.id].include?(official.id)
            next if datetime_official_usage[game_datetime].include?(official.id)

            game_official_usage[game.id].add(official.id)
            datetime_official_usage[game_datetime].add(official.id)
            total_fillable += 1
            assignment_plan << {
              game: game,
              role: role,
              official: official,
              distance: eligible[:distance],
              concerns: eligible[:concerns]
            }
            assigned = true
            break
          end
        end
      end

      @theoretical_max = total_fillable
      @assignment_plan = assignment_plan
    end

    def generate_report
      report = []

      # Header
      report << "=" * 80
      report << "THEORETICAL MAXIMUM FILLABLE POSITIONS ANALYSIS"
      report << "=" * 80
      report << ""

      total_positions = games.count * 5
      percentage = (@theoretical_max.to_f / total_positions * 100).round(1)

      report << "📊 SUMMARY"
      report << "-" * 80
      report << "Total Positions: #{total_positions} (#{games.count} games × 5 roles)"
      report << "Theoretically Fillable: #{@theoretical_max} positions (#{percentage}%)"
      report << "Impossible to Fill: #{total_positions - @theoretical_max} positions"
      report << ""

      # Impossible positions
      impossible_positions = []
      difficult_positions = []

      @analysis_results.each do |game_id, roles|
        roles.each do |role, data|
          if data[:eligible_count] == 0
            impossible_positions << data
          elsif data[:eligible_count] <= 2
            difficult_positions << data
          end
        end
      end

      if impossible_positions.any?
        report << "❌ IMPOSSIBLE POSITIONS (0 eligible officials)"
        report << "-" * 80
        impossible_positions.each do |pos|
          report << "Game: #{pos[:game].name} (#{pos[:game].game_date.strftime('%m/%d/%Y %I:%M %p')})"
          report << "Role: #{pos[:role].upcase}"
          report << "Location: #{pos[:game].location}"
          report << ""

          # Show why each official is ineligible
          report << "  Why no officials are eligible:"
          reason_counts = Hash.new(0)
          pos[:ineligible_officials].each do |ineligible|
            ineligible[:reasons].each { |r| reason_counts[r] += 1 }
          end

          reason_counts.sort_by { |_, count| -count }.each do |reason, count|
            report << "    - #{reason} (#{count} officials)"
          end
          report << ""
        end
      end

      if difficult_positions.any?
        report << "⚠️  DIFFICULT POSITIONS (1-2 eligible officials)"
        report << "-" * 80
        difficult_positions.each do |pos|
          report << "Game: #{pos[:game].name} (#{pos[:game].game_date.strftime('%m/%d/%Y %I:%M %p')})"
          report << "Role: #{pos[:role].upcase}"
          report << "Eligible Officials: #{pos[:eligible_count]}"

          pos[:eligible_officials].each do |eligible|
            distance_str = eligible[:distance] ? "#{eligible[:distance].round(1)} mi" : "N/A"
            concerns_str = eligible[:concerns].any? ? " ⚠️  #{eligible[:concerns].join(', ')}" : ""
            report << "  ✓ #{eligible[:official].name} (#{distance_str})#{concerns_str}"
          end
          report << ""
        end
      end

      # Per-game breakdown
      report << "📋 PER-GAME BREAKDOWN"
      report << "-" * 80

      games.each do |game|
        roles_data = @analysis_results[game.id]
        fillable_count = roles_data.values.count { |r| r[:eligible_count] > 0 }

        status = fillable_count == 5 ? "✅" : fillable_count == 0 ? "❌" : "⚠️ "

        report << "#{status} #{game.name} - #{game.game_date.strftime('%m/%d/%Y %I:%M %p')}"
        report << "   Location: #{game.location}"
        report << "   Fillable: #{fillable_count}/5 positions"

        Assignment::ROLES.each_key do |role|
          role_data = roles_data[role]
          if role_data[:eligible_count] == 0
            report << "     ❌ #{role.upcase}: 0 eligible"
          elsif role_data[:eligible_count] <= 2
            report << "     ⚠️  #{role.upcase}: #{role_data[:eligible_count]} eligible"
          else
            report << "     ✓ #{role.upcase}: #{role_data[:eligible_count]} eligible"
          end
        end
        report << ""
      end

      # Constraint violation breakdown
      report << "📈 CONSTRAINT VIOLATION BREAKDOWN"
      report << "-" * 80

      violation_counts = {
        'Role capability' => 0,
        'Distance' => 0,
        'Availability' => 0,
        'Already assigned' => 0,
        'Other' => 0
      }

      @analysis_results.each do |_, roles|
        roles.each do |_, data|
          data[:ineligible_officials].each do |ineligible|
            ineligible[:reasons].each do |reason|
              if reason.include?('Cannot fill')
                violation_counts['Role capability'] += 1
              elsif reason.include?('Distance')
                violation_counts['Distance'] += 1
              elsif reason.include?('Not available')
                violation_counts['Availability'] += 1
              elsif reason.include?('Already assigned')
                violation_counts['Already assigned'] += 1
              else
                violation_counts['Other'] += 1
              end
            end
          end
        end
      end

      violation_counts.sort_by { |_, count| -count }.each do |violation, count|
        report << "#{violation}: #{count} occurrences"
      end
      report << ""

      # Per-official analysis
      report << "👥 PER-OFFICIAL ELIGIBLE POSITION COUNT"
      report << "-" * 80

      official_eligibility = Hash.new { |h, k| h[k] = { eligible: 0, total: 0 } }

      @analysis_results.each do |_, roles|
        roles.each do |_, data|
          data[:eligible_officials].each do |eligible|
            official_eligibility[eligible[:official]][:eligible] += 1
            official_eligibility[eligible[:official]][:total] += 1
          end

          data[:ineligible_officials].each do |ineligible|
            official_eligibility[ineligible[:official]][:total] += 1
          end
        end
      end

      official_eligibility.sort_by { |official, _| official.name }.each do |official, counts|
        percentage = (counts[:eligible].to_f / counts[:total] * 100).round(1)
        report << "#{official.name}: #{counts[:eligible]}/#{counts[:total]} positions (#{percentage}%)"
      end
      report << ""

      # Best-case assignment scenario
      if @assignment_plan.any?
        report << "🎯 ONE THEORETICAL OPTIMAL ASSIGNMENT SCENARIO"
        report << "-" * 80
        report << "This shows ONE possible way to achieve #{@theoretical_max} filled positions:"
        report << ""

        @assignment_plan.group_by { |a| a[:game] }.each do |game, assignments|
          report << "#{game.name} - #{game.game_date.strftime('%m/%d/%Y')}"
          assignments.sort_by { |a| Assignment::ROLES[a[:role]] }.each do |assignment|
            distance_str = assignment[:distance] ? "#{assignment[:distance].round(1)} mi" : "N/A"
            concerns_str = assignment[:concerns].any? ? " ⚠️  #{assignment[:concerns].join(', ')}" : ""
            report << "  #{assignment[:role].to_s.upcase.ljust(10)} → #{assignment[:official].name.ljust(20)} (#{distance_str})#{concerns_str}"
          end
          report << ""
        end
      end

      report << "=" * 80
      report << "This represents the BEST POSSIBLE OUTCOME given current constraints."
      report << "Use this as the baseline to evaluate AI assignment performance."
      report << "If AI achieves #{@theoretical_max}/#{total_positions}, it's perfect!"
      report << "=" * 80

      report.join("\n")
    end
  end
end
