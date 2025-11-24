class CreateAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :assignments do |t|
      t.references :game, null: false, foreign_key: true
      t.references :official, null: false, foreign_key: true
      t.references :assignment_attempt, null: true, foreign_key: true
      t.integer :role
      t.integer :tokens_used
      t.integer :duration_ms
      t.integer :score
      t.text :reasoning
      t.text :ai_response
      t.boolean :success, default: true

      t.timestamps
    end

    add_index :assignments, [:game_id, :official_id], unique: true, name: 'index_assignments_on_game_and_official'
    add_index :assignments, :role
    add_index :assignments, :success
  end
end
