class CreateRuleViolations < ActiveRecord::Migration[8.1]
  def change
    create_table :rule_violations do |t|
      t.references :assignment_evaluation, null: false, foreign_key: true
      t.references :assignment, null: false, foreign_key: true
      t.references :official, null: false, foreign_key: true
      t.references :rule, null: true, foreign_key: true
      t.integer :violation_type
      t.integer :severity
      t.text :description

      t.timestamps
    end
  end
end
