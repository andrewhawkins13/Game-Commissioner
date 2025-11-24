class AddTokenBreakdownToAssignmentAttempts < ActiveRecord::Migration[8.1]
  def change
    add_column :assignment_attempts, :prompt_tokens_total, :integer
    add_column :assignment_attempts, :completion_tokens_total, :integer
  end
end
