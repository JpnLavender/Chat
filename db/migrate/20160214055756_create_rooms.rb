class CreateRooms < ActiveRecord::Migration
  def change
    create_table :rooms do |t|
      t.string :name
      t.string :token
      t.boolean :admin, default: true, nill: false
      t.boolean :public, default: false, null: false
      t.timestamps null: false
    end
  end
end
