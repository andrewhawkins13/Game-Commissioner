class CreateRules < ActiveRecord::Migration[8.1]
  def change
    create_table :rules do |t|
      t.references :official, null: false, foreign_key: true
      t.text :rule_text
      t.boolean :active

      t.timestamps
    end
  end
end
