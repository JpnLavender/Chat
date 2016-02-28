class CreateRooms < ActiveRecord::Migration
  def change
    create_table :rooms do |t|
      t.string :name
      t.boolean :range, default: false, null: false
      t.timestamps null: false
    end
  end
end
