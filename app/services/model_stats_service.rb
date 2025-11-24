class ModelStatsService
  class << self
    # Returns statistics for a specific model
    def stats_for_model(model_name)
      attempts = AssignmentAttempt.by_model(model_name).successful

      return default_stats if attempts.empty?

      {
        total_attempts: attempts.count,
        avg_success_rate: calculate_avg_success_rate(attempts),
        avg_tokens: calculate_avg_tokens(attempts),
        avg_duration_seconds: calculate_avg_duration(attempts),
        total_positions_filled: attempts.sum(:assignments_made),
        total_positions_failed: attempts.sum(:assignments_failed),
        worst_success_rate: attempts.minimum(:assignments_made).to_f / attempts.maximum(:total_positions).to_f * 100,
        best_success_rate: attempts.maximum(:assignments_made).to_f / attempts.minimum(:total_positions).to_f * 100,
        first_used: attempts.minimum(:created_at),
        last_used: attempts.maximum(:created_at)
      }
    end

    # Returns whether a model has been used
    def model_used?(model_name)
      AssignmentAttempt.by_model(model_name).exists?
    end

    # Returns a leaderboard of models ranked by performance
    def leaderboard
      model_names = AssignmentAttempt.distinct.pluck(:ollama_model)

      models = model_names.map do |model_name|
        attempts = AssignmentAttempt.by_model(model_name).successful
        next if attempts.empty?

        {
          name: model_name,
          total_attempts: attempts.count,
          avg_success_rate: calculate_avg_success_rate(attempts),
          avg_tokens: calculate_avg_tokens(attempts),
          avg_duration_seconds: calculate_avg_duration(attempts),
          token_efficiency_ratio: calculate_token_efficiency(attempts),
          score: calculate_performance_score(attempts)
        }
      end.compact

      models.sort_by { |m| -m[:score] }
    end

    # Returns recent assignment attempts for a model
    def recent_attempts(model_name, limit: 10)
      AssignmentAttempt.by_model(model_name).recent.limit(limit)
    end

    # Returns trend data for a model over the specified number of days
    def model_trends(model_name, days: 30)
      start_date = days.days.ago.beginning_of_day
      attempts = AssignmentAttempt.by_model(model_name)
                                   .where('created_at >= ?', start_date)
                                   .order(:created_at)

      # Group by day and calculate daily metrics
      trends = attempts.group_by { |a| a.created_at.to_date }.map do |date, day_attempts|
        successful = day_attempts.select { |a| a.status == 'completed' }
        {
          date: date,
          attempts: day_attempts.count,
          avg_success_rate: successful.empty? ? 0 : successful.sum(&:fill_rate) / successful.count,
          avg_tokens: successful.empty? ? 0 : successful.sum { |a| a.total_tokens || 0 } / successful.count,
          avg_duration: successful.empty? ? 0 : successful.sum { |a| a.duration_seconds || 0 } / successful.count
        }
      end

      trends.sort_by { |t| t[:date] }
    end

    # Returns comparison data for multiple models
    def compare_models(model_names)
      model_names.map do |model_name|
        stats = stats_for_model(model_name)
        {
          name: model_name,
          stats: stats,
          used: stats[:total_attempts] > 0
        }
      end
    end

    private

    def default_stats
      {
        total_attempts: 0,
        avg_success_rate: 0.0,
        avg_tokens: 0.0,
        avg_duration_seconds: 0.0,
        total_positions_filled: 0,
        total_positions_failed: 0,
        worst_success_rate: 0.0,
        best_success_rate: 0.0,
        first_used: nil,
        last_used: nil
      }
    end

    def calculate_avg_success_rate(attempts)
      rates = attempts.map(&:fill_rate).compact
      return 0.0 if rates.empty?
      (rates.sum / rates.count.to_f).round(2)
    end

    def calculate_avg_tokens(attempts)
      tokens = attempts.map(&:total_tokens).compact
      return 0.0 if tokens.empty?
      (tokens.sum / tokens.count.to_f).round(2)
    end

    def calculate_avg_duration(attempts)
      durations = attempts.map(&:duration_seconds).compact
      return 0.0 if durations.empty?
      (durations.sum / durations.count.to_f).round(2)
    end

    def calculate_token_efficiency(attempts)
      avg_rate = calculate_avg_success_rate(attempts)
      avg_tokens = calculate_avg_tokens(attempts)
      return 0.0 if avg_tokens.zero?
      (avg_rate / avg_tokens * 1000).round(2)
    end

    def calculate_performance_score(attempts)
      success_rate = calculate_avg_success_rate(attempts)
      token_efficiency = calculate_token_efficiency(attempts)
      duration = calculate_avg_duration(attempts)

      # Normalize duration (lower is better, so invert)
      duration_score = duration.zero? ? 100 : [100 - (duration / 10), 0].max

      # Weighted score: 50% success rate, 30% token efficiency, 20% speed
      (success_rate * 0.5 + token_efficiency * 0.3 + duration_score * 0.2).round(2)
    end
  end
end
