class AddTheoreticalMaxToAssignments < ActiveRecord::Migration[8.1]
  def change
    add_column :assignment_attempts, :theoretical_max_report, :text
    add_column :assignment_attempts, :theoretical_max_fillable, :integer
    add_column :assignment_evaluations, :theoretical_comparison, :jsonb
  end
end
