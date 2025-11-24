class OfficialRole < ApplicationRecord
  include RoleEnumerable

  belongs_to :official

  validates :role, presence: true, uniqueness: { scope: :official_id }
end
