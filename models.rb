require 'bundler/setup'
Bundler.require

if development?
  ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
end

#unless ENV['RACK_ENV'] == 'production'
#    ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
#end
class User < ActiveRecord::Base
  has_many :answers
  has_many :tokens
  has_many :talks
  has_many :chats
  has_many :userrooms,  through: :appointments
  has_many :friends
  has_secure_password
  validates :mail,
    presence: true,
    format: {with:/.+@.+/}
  validates :password, confirmation: true,
    unless: Proc.new { |a| a.password.blank? }
end

  class Chat < ActiveRecord::Base
    belongs_to :user
  end

  class Token < ActiveRecord::Base
    belongs_to :user
    # uuid: string, expire_at: datetime
  end

  class Talk < ActiveRecord::Base
    belongs_to :user
  end

  class Users < ActiveRecord::Base
  end

  class Userroom < ActiveRecord::Base
    has_many :user,  through: :appointments
  end
