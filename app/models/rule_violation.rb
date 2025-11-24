class RuleViolation < ApplicationRecord
  belongs_to :assignment_evaluation
  belongs_to :assignment
  belongs_to :official
  belongs_to :rule, optional: true

  enum :violation_type, {
    distance: 0,
    back_to_back: 1,
    custom_rule: 2,
    role_mismatch: 3,
    role_capability: 4,
    availability: 5,
    simultaneous_games: 6,
    double_booking: 7
  }
  enum :severity, { critical: 0, major: 1, minor: 2 }

  validates :violation_type, presence: true
  validates :severity, presence: true
  validates :description, presence: true

  # Auto-update counter caches on AssignmentEvaluation based on violation_type
  after_create :increment_type_counter
  after_destroy :decrement_type_counter

  scope :critical_violations, -> { where(severity: :critical) }
  scope :by_severity, -> { order(severity: :asc) }
  scope :by_type, ->(type) { where(violation_type: type) }

  def severity_label
    case severity
    when "critical" then "🔴 Critical"
    when "major" then "🟠 Major"
    when "minor" then "🟡 Minor"
    end
  end

  private

  # Map violation types to their corresponding counter column names
  def counter_column
    case violation_type
    when "distance"
      :distance_violations_count
    when "back_to_back", "simultaneous_games", "double_booking", "availability"
      :conflict_violations_count
    when "custom_rule", "role_mismatch", "role_capability"
      :rule_violations_count
    end
  end

  def increment_type_counter
    column = counter_column
    return unless column

    assignment_evaluation.increment!(column)
  end

  def decrement_type_counter
    column = counter_column
    return unless column

    assignment_evaluation.decrement!(column)
  end
end
