require 'bundler/setup'
Bundler.require

if development?
  ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
end

#unless ENV['RACK_ENV'] == 'production'
#    ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
#end
#
class User < ActiveRecord::Base
  has_many :tokens
  has_many :chats
  has_many :rooms,  through: :userrooms
  has_many :userrooms
  has_many :friends
  has_many :alerts
  has_secure_password
  validates :mail,
    presence: true,
    format: {with:/.+@.+/}
  validates :password, confirmation: true,
    unless: Proc.new { |a| a.password.blank? }
end

class Chat < ActiveRecord::Base
  belongs_to :room
  belongs_to :user
  paginates_per 200
end

class Room < ActiveRecord::Base
  has_many :users,  through: :userrooms
  has_many :chats
  has_many :userrooms
  paginates_per 24 
end

class Userroom < ActiveRecord::Base
  enum status: {normal: 0, admin: 1, watch: 2, block: 3}
  validates :user_id, uniqueness: { scope: [:room_id] } 
  belongs_to :room
  belongs_to :user
  has_many :friends
end

class Token < ActiveRecord::Base
  belongs_to :user
end

class Friend < ActiveRecord::Base
  enum status: {friend: 0, intimate: 1, block: 2}
  belongs_to :user
  belongs_to :userroom
end

class Alert < ActiveRecord::Base
  belongs_to :user
end

