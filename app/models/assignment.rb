class Assignment < ApplicationRecord
  include RoleEnumerable

  belongs_to :game
  belongs_to :official
  belongs_to :assignment_attempt, optional: true
  has_many :rule_violations, dependent: :destroy

  validates :role, presence: true, uniqueness: { scope: :game_id, message: "has already been assigned for this game" }
  validates :official_id, uniqueness: { scope: :game_id, message: "is already assigned to this game" }, if: :success?
  validates :game_id, presence: true
  validates :official_id, presence: true, if: :success?
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  validate :official_can_fill_role, if: :success?
  validate :role_is_open_for_game, if: -> { success? && ai_assigned? }

  scope :ai_assigned, -> { where.not(assignment_attempt_id: nil) }
  scope :manual_assigned, -> { where(assignment_attempt_id: nil) }

  def ai_assigned?
    assignment_attempt_id.present?
  end

  def has_violations?
    rule_violations.any?
  end

  private

  def official_can_fill_role
    return unless official && role

    unless official.can_fill_role?(role)
      errors.add(:official, "cannot fill the #{role} role")
    end
  end

  def role_is_open_for_game
    return unless game && role

    unless game.open_positions.include?(role)
      errors.add(:role, "is not an open position for this game (already filled or not needed). Open positions: #{game.open_positions.join(', ')}")
    end
  end
end
