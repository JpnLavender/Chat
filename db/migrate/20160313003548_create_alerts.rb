class CreateAlerts < ActiveRecord::Migration
  def change
    create_table :alerts do |t|
      t.string :title
      t.integer :user_id
      t.timestamp null: false
    end
  end
end
