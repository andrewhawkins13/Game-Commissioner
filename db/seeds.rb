# Clear existing data in development
if Rails.env.development?
  puts "Clearing existing data..."
  Assignment.destroy_all
  Game.destroy_all
  Availability.destroy_all
  OfficialRole.destroy_all
  Rule.destroy_all
  Official.destroy_all
end

puts "Creating officials..."

# Create officials with different specializations
officials_data = [
  {
    name: "John Smith",
    email: "john.smith@example.com",
    phone: "555-0101",
    home_address: "123 Main St, Portland, OR 97201",
    latitude: 45.5152,
    longitude: -122.6784,
    max_distance: 20,
    roles: [:referee, :hl],
    rules: [
      "Only travels within 20 miles of home",
      "Doesn't work back to back days",
      "Won't work at Jefferson High School"
    ]
  },
  {
    name: "Sarah Johnson",
    email: "sarah.johnson@example.com",
    phone: "555-0102",
    home_address: "456 Oak Ave, Portland, OR 97202",
    latitude: 45.4865,
    longitude: -122.6535,
    max_distance: 30,
    roles: [:referee, :uc, :bj],
    rules: [
      "Maximum 30 miles from home",
      "Prefers evening games after 6 PM",
      "Available Friday through Sunday only"
    ]
  },
  {
    name: "Mike Williams",
    email: "mike.williams@example.com",
    phone: "555-0103",
    home_address: "789 Pine St, Beaverton, OR 97005",
    latitude: 45.4871,
    longitude: -122.8037,
    max_distance: 25,
    roles: [:lj, :bj, :uc],
    rules: [
      "Won't travel more than 25 miles",
      "Can't work on Wednesdays"
    ]
  },
  {
    name: "Emily Davis",
    email: "emily.davis@example.com",
    phone: "555-0104",
    home_address: "321 Elm St, Portland, OR 97210",
    latitude: 45.5289,
    longitude: -122.6816,
    max_distance: 35,
    roles: [:referee, :hl, :lj],
    rules: [
      "Flexible with travel up to 35 miles",
      "No games at Lincoln High School"
    ]
  },
  {
    name: "Robert Brown",
    email: "robert.brown@example.com",
    phone: "555-0105",
    home_address: "654 Maple Dr, Hillsboro, OR 97124",
    latitude: 45.5228,
    longitude: -122.9359,
    max_distance: 15,
    roles: [:uc, :bj],
    rules: [
      "Only works within 15 miles",
      "No consecutive day assignments"
    ]
  },
  {
    name: "Jennifer Wilson",
    email: "jennifer.wilson@example.com",
    phone: "555-0106",
    home_address: "987 Cedar Ln, Lake Oswego, OR 97034",
    latitude: 45.4207,
    longitude: -122.7068,
    max_distance: 40,
    roles: [:referee, :hl, :lj, :bj, :uc],
    rules: [
      "Can fill any role",
      "Willing to travel up to 40 miles",
      "Prefers not to work at Madison High School"
    ]
  },
  {
    name: "David Martinez",
    email: "david.martinez@example.com",
    phone: "555-0107",
    home_address: "234 Birch St, Portland, OR 97214",
    latitude: 45.5155,
    longitude: -122.6400,
    max_distance: 30,
    roles: [:referee, :hl],
    rules: [
      "Maximum 30 miles from home",
      "No back-to-back games"
    ]
  },
  {
    name: "Lisa Anderson",
    email: "lisa.anderson@example.com",
    phone: "555-0108",
    home_address: "567 Spruce Ave, Portland, OR 97220",
    latitude: 45.5332,
    longitude: -122.5622,
    max_distance: 45,
    roles: [:lj, :bj, :uc],
    rules: [
      "Can travel up to 45 miles",
      "Available any day except Thursdays"
    ]
  },
  {
    name: "Thomas Garcia",
    email: "thomas.garcia@example.com",
    phone: "555-0109",
    home_address: "890 Willow Rd, Portland, OR 97203",
    latitude: 45.5940,
    longitude: -122.7445,
    max_distance: 20,
    roles: [:referee, :uc, :bj, :lj],
    rules: [
      "Only works within 20 miles",
      "Cannot work consecutive days",
      "No games at Grant High School"
    ]
  }
]

officials_data.each do |data|
  official = Official.create!(
    name: data[:name],
    email: data[:email],
    phone: data[:phone],
    home_address: data[:home_address],
    latitude: data[:latitude],
    longitude: data[:longitude],
    max_distance: data[:max_distance]
  )

  # Add roles
  data[:roles].each do |role|
    official.official_roles.create!(role: role)
  end

  # Add rules
  data[:rules].each do |rule_text|
    official.rules.create!(rule_text: rule_text, active: true)
  end

  puts "  Created official: #{official.name}"
end

puts "\nCreating games..."

# Create sample games with some on back-to-back days
games_data = [
  # Day 3 - First game
  {
    name: "Lincoln vs Roosevelt",
    game_date: 3.days.from_now.change(hour: 19, min: 0),
    location: "Lincoln High School",
    address: "1600 SW Salmon St, Portland, OR 97205",
    latitude: 45.5186,
    longitude: -122.6911
  },
  # Day 4 - Back-to-back with Day 3
  {
    name: "Jefferson vs Madison",
    game_date: 4.days.from_now.change(hour: 18, min: 30),
    location: "Jefferson High School",
    address: "5210 N Kerby Ave, Portland, OR 97217",
    latitude: 45.5580,
    longitude: -122.6748
  },
  # Day 5 - Back-to-back with Day 4
  {
    name: "Grant vs Cleveland",
    game_date: 5.days.from_now.change(hour: 20, min: 0),
    location: "Grant High School",
    address: "2245 NE 36th Ave, Portland, OR 97212",
    latitude: 45.5407,
    longitude: -122.6263
  },
  # Day 7 - Gap day
  {
    name: "Wilson vs Benson",
    game_date: 7.days.from_now.change(hour: 19, min: 0),
    location: "Wilson High School",
    address: "1151 SW Vermont St, Portland, OR 97219",
    latitude: 45.4776,
    longitude: -122.7109
  },
  # Day 8 - Back-to-back with Day 7
  {
    name: "Franklin vs Marshall",
    game_date: 8.days.from_now.change(hour: 18, min: 0),
    location: "Franklin High School",
    address: "5405 SE Woodward St, Portland, OR 97206",
    latitude: 45.4825,
    longitude: -122.6087
  },
  # Day 10 - Gap day (two games at same time)
  {
    name: "Sunset vs Beaverton",
    game_date: 10.days.from_now.change(hour: 19, min: 30),
    location: "Sunset High School",
    address: "13840 NW Cornell Rd, Portland, OR 97229",
    latitude: 45.5410,
    longitude: -122.8399
  },
  {
    name: "Aloha vs Century",
    game_date: 10.days.from_now.change(hour: 19, min: 30),
    location: "Aloha High School",
    address: "18550 SW Kinnaman Rd, Aloha, OR 97078",
    latitude: 45.4893,
    longitude: -122.8711
  },
  # Day 11 - Back-to-back with Day 10
  {
    name: "Beaverton vs Southridge",
    game_date: 11.days.from_now.change(hour: 19, min: 0),
    location: "Beaverton High School",
    address: "13000 SW 2nd St, Beaverton, OR 97005",
    latitude: 45.4760,
    longitude: -122.8050
  },
  # Day 14 - Standalone game
  {
    name: "Central Catholic vs Jesuit",
    game_date: 14.days.from_now.change(hour: 20, min: 0),
    location: "Central Catholic High School",
    address: "2401 SE Stark St, Portland, OR 97214",
    latitude: 45.5193,
    longitude: -122.6407
  }
]

games_data.each do |data|
  game = Game.create!(
    name: data[:name],
    game_date: data[:game_date],
    location: data[:location],
    address: data[:address],
    latitude: data[:latitude],
    longitude: data[:longitude],
    status: :scheduled
  )

  puts "  Created game: #{game.name} on #{game.game_date.strftime('%B %d at %I:%M %p')}"
end

puts "\nCreating availability windows..."

# Get officials by name for creating specific availability scenarios
sarah = Official.find_by(name: "Sarah Johnson")
mike = Official.find_by(name: "Mike Williams")
emily = Official.find_by(name: "Emily Davis")
robert = Official.find_by(name: "Robert Brown")
jennifer = Official.find_by(name: "Jennifer Wilson")

# Scenario 1: Sarah Johnson - "Available Friday through Sunday only"
# Create availability only for weekend dates (this will conflict with weekday games)
if sarah
  # Weekend availability window 1 (covers Day 3-5 if they fall on weekend, otherwise excludes them)
  first_friday = 3.days.from_now.beginning_of_week + 4.days
  sarah.availabilities.create!(
    start_time: first_friday.change(hour: 0, min: 0),
    end_time: (first_friday + 2.days).end_of_day
  )

  # Weekend availability window 2 (next weekend)
  second_friday = first_friday + 7.days
  sarah.availabilities.create!(
    start_time: second_friday.change(hour: 0, min: 0),
    end_time: (second_friday + 2.days).end_of_day
  )

  puts "  Created weekend-only availability for #{sarah.name} (#{sarah.availabilities.count} windows)"
end

# Scenario 2: Mike Williams - "Can't work on Wednesdays"
# Create availability that excludes Wednesdays (all days except Wednesday)
if mike
  # Find the next Wednesday
  next_wednesday = 1.day.from_now
  next_wednesday += 1.day until next_wednesday.wday == 3 # 3 = Wednesday

  # Availability before Wednesday
  mike.availabilities.create!(
    start_time: Time.current.beginning_of_day,
    end_time: (next_wednesday - 1.day).end_of_day
  )

  # Availability after Wednesday (Thursday through end of month)
  mike.availabilities.create!(
    start_time: (next_wednesday + 1.day).beginning_of_day,
    end_time: 30.days.from_now.end_of_day
  )

  puts "  Created no-Wednesday availability for #{mike.name} (excludes #{next_wednesday.strftime('%b %d')})"
end

# Scenario 3: Emily Davis - Only available for first week of games
# This creates a gap where she's unavailable for later games
if emily
  emily.availabilities.create!(
    start_time: Time.current.beginning_of_day,
    end_time: 7.days.from_now.end_of_day
  )

  puts "  Created limited availability for #{emily.name} (Days 0-7 only)"
end

# Scenario 4: Robert Brown - Has a vacation gap (unavailable Days 9-12)
# Available before and after, but not during
if robert
  # Available for early games
  robert.availabilities.create!(
    start_time: Time.current.beginning_of_day,
    end_time: 8.days.from_now.end_of_day
  )

  # Back from vacation for later games
  robert.availabilities.create!(
    start_time: 13.days.from_now.beginning_of_day,
    end_time: 30.days.from_now.end_of_day
  )

  puts "  Created vacation gap for #{robert.name} (unavailable Days 9-12)"
end

# Scenario 5: Jennifer Wilson - Fully available (create broad window)
# This demonstrates that having availability records can also confirm availability
if jennifer
  jennifer.availabilities.create!(
    start_time: Time.current.beginning_of_day,
    end_time: 60.days.from_now.end_of_day
  )

  puts "  Created full availability for #{jennifer.name} (always available)"
end

# Note: Other officials (John, David, Lisa, Thomas) have NO availability records
# They will be treated as "always available" by default

puts "\nSeed data created successfully!"
puts "#{Official.count} officials created"
puts "#{Game.count} games created"
puts "#{Rule.count} rules created"
puts "#{OfficialRole.count} official roles created"
puts "#{Availability.count} availability windows created"
puts "\nAvailability Scenarios:"
puts "  • Sarah Johnson: Weekend only (will conflict with weekday games)"
puts "  • Mike Williams: No Wednesdays (will exclude Wednesday games)"
puts "  • Emily Davis: Only Days 0-7 (unavailable for later games)"
puts "  • Robert Brown: Vacation Days 9-12 (gap in availability)"
puts "  • Jennifer Wilson: Fully available (broad window)"
puts "  • Others (4 officials): No availability records (always available by default)"
puts "\nYou can now:"
puts "1. Visit the games page to manually assign officials"
puts "2. Click 'Assign Open Games' to let AI assign officials and see availability filtering in action"
puts "\nNote: Make sure Ollama is running with a model (e.g., llama3.2) for AI assignments to work."
