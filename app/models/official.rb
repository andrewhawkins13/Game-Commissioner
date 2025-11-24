class Official < ApplicationRecord
  has_many :assignments, dependent: :destroy
  has_many :games, through: :assignments
  has_many :rules, dependent: :destroy
  has_many :official_roles, dependent: :destroy
  has_many :availabilities, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :max_distance, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :phone, format: { with: /\A[\d\s\-\(\)\.+]+\z/, message: "must be a valid phone number" }, allow_blank: true

  def can_fill_role?(role)
    official_roles.exists?(role: role)
  end

  def assigned_on_date?(date)
    assignments.joins(:game).where("DATE(games.game_date) = ?", date.to_date).exists?
  end

  def distance_to(game)
    DistanceCalculationService.between_game_and_official(game, self)
  end

  def within_travel_distance?(game)
    DistanceCalculationService.within_travel_distance?(game, self)
  end

  # Check if the official is available for a specific date
  def available_on_date?(date)
    # If no availabilities are defined, assume always available
    return true if availabilities.empty?

    # Check if any availability window includes this date
    availabilities.any? { |avail| avail.includes_date?(date) }
  end

  # Check if the official is available for a specific game
  def available_for_game?(game)
    available_on_date?(game.game_date)
  end
end
