class CreateAlerts < ActiveRecord::Migration
  def change
    create_table :alerts do |t|
      t.string :title
      t.integer :user_id
      t.string :expired_at
      t.timestamps null: false
    end
  end
end
