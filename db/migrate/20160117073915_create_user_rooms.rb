class CreateUserRooms < ActiveRecord::Migration
  def change
    create_table :userrooms do |t|
      t.integer :user_id
      t.integer :room_id
      t.integer :staus, default: 0, null: false
      t.timestamps null: false
    end
  end
end
