class AddStrategyToAssignmentAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :assignment_attempts, :strategy, :string
  end
end
