class CreateChats < ActiveRecord::Migration
  def change
    create_table :chats do |t|
      t.string :text
      t.integer :room_id
      t.integer :user_id
      t.timestamps null: false
    end
  end
end
