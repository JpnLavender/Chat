class AddAlertidToFriends < ActiveRecord::Migration
  def change
		add_column :friends, :alert_id ,:string
  end
end
