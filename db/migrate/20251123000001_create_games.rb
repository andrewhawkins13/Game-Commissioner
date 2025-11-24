class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :name
      t.datetime :game_date
      t.string :location
      t.string :address
      t.decimal :latitude
      t.decimal :longitude
      t.integer :status

      t.timestamps
    end

    add_index :games, :status
  end
end
