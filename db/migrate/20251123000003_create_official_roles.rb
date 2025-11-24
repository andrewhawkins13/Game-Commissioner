class CreateOfficialRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :official_roles do |t|
      t.references :official, null: false, foreign_key: true
      t.integer :role

      t.timestamps
    end

    add_index :official_roles, [:official_id, :role]
  end
end
