class CreateOfficials < ActiveRecord::Migration[8.1]
  def change
    create_table :officials do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.integer :max_distance
      t.string :home_address
      t.decimal :latitude
      t.decimal :longitude

      t.timestamps
    end
  end
end
