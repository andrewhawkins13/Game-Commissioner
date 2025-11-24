class CreateAssignmentAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :assignment_attempts do |t|
      t.string :ollama_model
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_positions
      t.integer :total_tokens
      t.integer :status
      t.integer :total_games, default: 0
      t.integer :games_processed
      t.text :error_message
      t.text :prompt
      t.text :ai_response
      t.text :detailed_log
      t.integer :assignments_made, default: 0
      t.integer :assignments_failed, default: 0

      t.timestamps
    end

    add_index :assignment_attempts, :status
  end
end
