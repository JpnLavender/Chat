class CreateTalks < ActiveRecord::Migration
  def change
    create_table :talks do |t|
      t.string :talk
      t.integer :user_name
      t.timestamps null: false
    end
  end
end
