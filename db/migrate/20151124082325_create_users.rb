class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :user_name
      t.string :introduction
      t.string :mail
      t.string :age
      t.string :color
      t.string :password_digest
      t.timestamps null: false
    end
  end
end
