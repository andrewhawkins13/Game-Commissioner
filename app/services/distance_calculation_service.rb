class DistanceCalculationService
  # Calculate distance between two points in miles using Haversine formula
  # Returns distance in miles, or nil if any coordinates are missing
  def self.calculate(lat1, lon1, lat2, lon2)
    return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)

    rad_per_deg = Math::PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 * 3.28084 / 5280 # Convert to miles

    dlat_rad = (lat2 - lat1) * rad_per_deg
    dlon_rad = (lon2 - lon1) * rad_per_deg

    lat1_rad = lat1 * rad_per_deg
    lat2_rad = lat2 * rad_per_deg

    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    (rm * c).round(2)
  end

  # Calculate distance between a game and an official
  # Returns distance in miles, or nil if either location is missing
  def self.between_game_and_official(game, official)
    calculate(
      game.latitude,
      game.longitude,
      official.latitude,
      official.longitude
    )
  end

  # Check if an official is within their maximum travel distance for a game
  # Returns true if within distance, true if no max_distance set, false otherwise
  def self.within_travel_distance?(game, official)
    return true if official.max_distance.nil?
    return true if game.latitude.nil? || game.longitude.nil?
    return true if official.latitude.nil? || official.longitude.nil?

    distance = between_game_and_official(game, official)
    return false if distance.nil?

    distance <= official.max_distance
  end
end
