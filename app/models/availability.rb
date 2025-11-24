# frozen_string_literal: true

# Represents an official's availability window
# Used to track when officials are available for game assignments
class Availability < ApplicationRecord
  belongs_to :official

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  scope :active, -> { where("end_time >= ?", Time.current) }
  scope :for_date, ->(date) {
    where("DATE(start_time) <= ? AND DATE(end_time) >= ?", date, date)
  }

  # Check if this availability window includes a specific date/time
  def includes_time?(time)
    time >= start_time && time <= end_time
  end

  # Check if this availability window includes a specific date
  def includes_date?(date)
    date_start = date.to_date.beginning_of_day
    date_end = date.to_date.end_of_day
    start_time <= date_end && end_time >= date_start
  end

  # Check if this availability overlaps with another availability window
  def overlaps_with?(other_availability)
    start_time <= other_availability.end_time && end_time >= other_availability.start_time
  end

  # Duration of the availability window in hours
  def duration_hours
    ((end_time - start_time) / 1.hour).round(1)
  end

  private

  def end_time_after_start_time
    return unless end_time.present? && start_time.present?

    if end_time <= start_time
      errors.add(:end_time, "must be after start time")
    end
  end
end
