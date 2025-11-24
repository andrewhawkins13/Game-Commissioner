# frozen_string_literal: true

namespace :analysis do
  desc "Calculate the theoretical maximum fillable positions from seed data"
  task theoretical_max: :environment do
    puts "\nAnalyzing theoretical maximum fillable positions..."
    puts "This will take a moment...\n\n"

    service = Analysis::TheoreticalMaxAnalysisService.new
    report = service.perform

    puts report

    # Optionally save to file
    if ENV['SAVE_REPORT']
      filename = "tmp/theoretical_max_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt"
      File.write(filename, report)
      puts "\n✅ Report saved to: #{filename}"
    end
  end

  desc "Show eligibility matrix for a specific game"
  task :game_eligibility, [:game_id] => :environment do |_t, args|
    if args[:game_id].blank?
      puts "Usage: rake analysis:game_eligibility[GAME_ID]"
      puts "\nAvailable games:"
      Game.order(:game_date).each do |game|
        puts "  ID: #{game.id} - #{game.name} (#{game.game_date.strftime('%m/%d/%Y')})"
      end
      exit
    end

    game = Game.find_by(id: args[:game_id])
    unless game
      puts "Game not found with ID: #{args[:game_id]}"
      exit
    end

    service = Analysis::TheoreticalMaxAnalysisService.new
    service.send(:analyze_all_positions)

    puts "\n" + "=" * 80
    puts "ELIGIBILITY ANALYSIS FOR: #{game.name}"
    puts "Date: #{game.game_date.strftime('%A, %B %d, %Y at %I:%M %p')}"
    puts "Location: #{game.location}"
    puts "=" * 80
    puts ""

    Assignment::ROLES.each_key do |role|
      position_data = service.analysis_results[game.id][role]

      puts "#{role.upcase} POSITION"
      puts "-" * 80

      if position_data[:eligible_count] == 0
        puts "❌ NO ELIGIBLE OFFICIALS"
        puts ""
        puts "Ineligibility reasons:"

        reason_counts = Hash.new(0)
        position_data[:ineligible_officials].each do |ineligible|
          ineligible[:reasons].each { |r| reason_counts[r] += 1 }
        end

        reason_counts.each do |reason, count|
          puts "  - #{reason} (#{count} officials)"
        end
      else
        puts "✅ #{position_data[:eligible_count]} eligible official(s)"
        puts ""

        position_data[:eligible_officials].each do |eligible|
          distance = eligible[:distance] ? "#{eligible[:distance].round(1)} miles" : "Distance N/A"
          puts "  ✓ #{eligible[:official].name.ljust(25)} (#{distance})"

          if eligible[:concerns].any?
            eligible[:concerns].each do |concern|
              puts "    ⚠️  #{concern}"
            end
          end
        end

        if position_data[:ineligible_officials].any?
          puts ""
          puts "  Ineligible officials:"
          position_data[:ineligible_officials].first(3).each do |ineligible|
            puts "    ✗ #{ineligible[:official].name}: #{ineligible[:reasons].first}"
          end

          if position_data[:ineligible_officials].length > 3
            puts "    ... and #{position_data[:ineligible_officials].length - 3} more"
          end
        end
      end

      puts ""
    end
  end

  desc "Show eligibility for a specific official"
  task :official_eligibility, [:official_id] => :environment do |_t, args|
    if args[:official_id].blank?
      puts "Usage: rake analysis:official_eligibility[OFFICIAL_ID]"
      puts "\nAvailable officials:"
      Official.order(:name).each do |official|
        puts "  ID: #{official.id} - #{official.name}"
      end
      exit
    end

    official = Official.find_by(id: args[:official_id])
    unless official
      puts "Official not found with ID: #{args[:official_id]}"
      exit
    end

    service = Analysis::TheoreticalMaxAnalysisService.new
    service.send(:analyze_all_positions)

    puts "\n" + "=" * 80
    puts "ELIGIBILITY ANALYSIS FOR: #{official.name}"
    puts "Max Distance: #{official.max_distance} miles"
    puts "Roles: #{official.official_roles.pluck(:role).map { |r| Assignment::ROLES.key(r) }.join(', ')}"
    puts "=" * 80
    puts ""

    if official.rules.active.any?
      puts "ACTIVE RULES:"
      official.rules.active.each do |rule|
        puts "  - #{rule.rule_text}"
      end
      puts ""
    end

    if official.availabilities.any?
      puts "AVAILABILITY WINDOWS:"
      official.availabilities.order(:start_time).each do |avail|
        puts "  - #{avail.start_time.strftime('%m/%d/%Y %I:%M %p')} to #{avail.end_time.strftime('%m/%d/%Y %I:%M %p')}"
      end
      puts ""
    else
      puts "AVAILABILITY: Always available (no restrictions)"
      puts ""
    end

    eligible_count = 0
    total_positions = 0

    Game.order(:game_date).each do |game|
      game_eligible = []
      game_ineligible = []

      Assignment::ROLES.each_key do |role|
        total_positions += 1
        position_data = service.analysis_results[game.id][role]

        eligible_for_this = position_data[:eligible_officials].find { |e| e[:official].id == official.id }

        if eligible_for_this
          eligible_count += 1
          game_eligible << {
            role: role,
            distance: eligible_for_this[:distance],
            concerns: eligible_for_this[:concerns]
          }
        else
          ineligible_for_this = position_data[:ineligible_officials].find { |i| i[:official].id == official.id }
          if ineligible_for_this
            game_ineligible << {
              role: role,
              reasons: ineligible_for_this[:reasons]
            }
          end
        end
      end

      if game_eligible.any?
        puts "✅ #{game.name} - #{game.game_date.strftime('%m/%d/%Y')}"
        puts "   Eligible for: #{game_eligible.map { |e| e[:role].upcase }.join(', ')}"

        game_eligible.each do |e|
          if e[:concerns].any?
            puts "   ⚠️  #{e[:role].upcase}: #{e[:concerns].join(', ')}"
          end
        end
      elsif game_ineligible.any?
        puts "❌ #{game.name} - #{game.game_date.strftime('%m/%d/%Y')}"
        reasons = game_ineligible.flat_map { |i| i[:reasons] }.uniq
        puts "   Reasons: #{reasons.join('; ')}"
      end

      puts ""
    end

    percentage = (eligible_count.to_f / total_positions * 100).round(1)
    puts "=" * 80
    puts "TOTAL: Eligible for #{eligible_count}/#{total_positions} positions (#{percentage}%)"
    puts "=" * 80
  end
end
