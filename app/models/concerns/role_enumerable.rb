# frozen_string_literal: true

# Shared role enumeration for Assignment and OfficialRole models
# This ensures role definitions stay synchronized across the application
module RoleEnumerable
  extend ActiveSupport::Concern

  # Official position roles in football games
  # These values must remain consistent as they're stored as integers in the database
  ROLES = {
    referee: 0,  # Head referee
    hl: 1,       # Head linesman
    lj: 2,       # Line judge
    bj: 3,       # Back judge
    uc: 4        # Umpire
  }.freeze

  included do
    enum :role, ROLES
  end

  class_methods do
    # Returns all available role names as symbols
    def available_roles
      ROLES.keys
    end

    # Returns the integer value for a given role
    def role_value(role_name)
      ROLES[role_name.to_sym]
    end
  end
end
