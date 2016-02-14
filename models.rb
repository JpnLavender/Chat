require 'bundler/setup'

if development?
  ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
end

#unless ENV['RACK_ENV'] == 'production'
#    ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
#end
class User < ActiveRecord::Base
  has_many :tokens
  has_many :rooms,  through: :userrooms
  has_secure_password
  validates :mail,
    presence: true,
    format: {with:/.+@.+/}
  validates :password, confirmation: true,
    unless: Proc.new { |a| a.password.blank? }
end

  class Chat < ActiveRecord::Base
    belongs_to :room
  end

  class Room < ActiveRecord::Base
    has_many :users,  through: :userrooms
    has_many :chats
  end

  class UserRoom < ActiveRecord::Base
    belongs_to :room
    belongs_to :user
  end

  class Token < ActiveRecord::Base
    belongs_to :user
  end

