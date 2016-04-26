class CreateFavorooms < ActiveRecord::Migration
  def change
		create_table :favorooms do |t|
			t.integer :user_id
			t.integer :room_id
		end
  end
end
