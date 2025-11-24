class AssignmentEvaluation < ApplicationRecord
  belongs_to :assignment_attempt
  has_many :rule_violations, dependent: :destroy

  validates :assignment_attempt_id, presence: true, uniqueness: true
  validates :overall_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Override attribute readers to ensure they never return nil
  def distance_violations_count
    self[:distance_violations_count] || 0
  end

  def conflict_violations_count
    self[:conflict_violations_count] || 0
  end

  def rule_violations_count
    self[:rule_violations_count] || 0
  end

  def total_violations
    rule_violations_count + distance_violations_count + conflict_violations_count
  end

  # Alias for view compatibility
  def total_violations_count
    total_violations
  end

  # Count of critical violations
  def critical_violations_count
    rule_violations.where(severity: :critical).count
  end

  def passed?
    overall_score && overall_score >= 70
  end

  def grade
    return "N/A" unless overall_score

    case overall_score
    when 90..100 then "A"
    when 80..89 then "B"
    when 70..79 then "C"
    when 60..69 then "D"
    else "F"
    end
  end

  # Theoretical max comparison methods
  def theoretical_max_fillable
    theoretical_comparison&.dig("theoretical_max_fillable")
  end

  def ai_assignments_made
    theoretical_comparison&.dig("ai_assignments_made")
  end

  def exceeded_theoretical_max?
    theoretical_comparison&.dig("exceeded_theoretical_max") || false
  end

  def efficiency_percentage
    theoretical_comparison&.dig("efficiency_percentage") || 0
  end

  def constraint_violations
    theoretical_comparison&.dig("constraint_violations") || []
  end

  def constraint_violations_count
    theoretical_comparison&.dig("constraint_violations_count") || 0
  end

  def violation_summary
    return "No violations detected." if constraint_violations.empty?

    summary = []
    summary << "Found #{constraint_violations_count} constraint violation(s):"

    constraint_violations.group_by { |v| v["type"] }.each do |type, violations|
      summary << "\n#{type.to_s.humanize} (#{violations.count}):"
      violations.each do |v|
        summary << "  - #{v['description']}"
      end
    end

    summary.join("\n")
  end

  def theoretical_comparison_summary
    return "No theoretical max data available" unless theoretical_max_fillable

    parts = []
    parts << "Theoretical Max: #{theoretical_max_fillable} positions"
    parts << "AI Assigned: #{ai_assignments_made} positions"
    parts << "Efficiency: #{efficiency_percentage}%"

    if exceeded_theoretical_max?
      parts << "⚠️  WARNING: Exceeded theoretical maximum by #{ai_assignments_made - theoretical_max_fillable} positions"
    end

    if constraint_violations_count > 0
      parts << "\n#{violation_summary}"
    end

    parts.join("\n")
  end
end
