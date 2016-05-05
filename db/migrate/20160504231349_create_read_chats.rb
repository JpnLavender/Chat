class CreateReadChats < ActiveRecord::Migration
  def change
		create_table :readchats do |t|
			t.integer :room_id
			t.integer :chat_id
			t.integer :userroom_id
		end
  end
end
