class CreateAssignmentEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :assignment_evaluations do |t|
      t.references :assignment_attempt, null: false, foreign_key: true
      t.string :judge_model
      t.integer :overall_score
      t.integer :rule_violations_count
      t.integer :distance_violations_count
      t.integer :conflict_violations_count
      t.text :evaluation_reasoning
      t.datetime :evaluated_at

      t.timestamps
    end
  end
end
