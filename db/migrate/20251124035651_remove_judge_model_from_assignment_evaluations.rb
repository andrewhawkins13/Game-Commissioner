class RemoveJudgeModelFromAssignmentEvaluations < ActiveRecord::Migration[8.1]
  def change
    remove_column :assignment_evaluations, :judge_model, :string
  end
end
