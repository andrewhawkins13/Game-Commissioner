class Rule < ApplicationRecord
  belongs_to :official

  validates :rule_text, presence: true

  scope :active, -> { where(active: true) }

  def self.for_official(official)
    where(official: official, active: true)
  end
end
