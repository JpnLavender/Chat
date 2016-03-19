class CreateAlerts < ActiveRecord::Migration
  def change
    create_table :alerts do |t|
      t.string :title
      t.string :url
      t.integer :user_id
      t.boolean :reading, default: false, null: false
      t.integer :status, default: 0, null: false
      t.timestamps null: false
    end
  end
end
