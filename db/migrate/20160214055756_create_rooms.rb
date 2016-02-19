class CreateRooms < ActiveRecord::Migration
  def change
    create_table :rooms do |t|
      t.string :name
      t.boolean :range, default: false, null: false
      t.boolean :room_admin, default: false, null: false
    end
  end
end
