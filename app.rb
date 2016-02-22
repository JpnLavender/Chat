require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'sinatra/json'
require './models.rb'
require 'csv'
require 'open-uri'
require 'time'
require 'active_support/all'
require 'pony'
require 'sinatra'
require 'sinatra/base'
require 'base64'
require 'securerandom'
use Rack::Session::Cookie
# ////////////////////////////////サイト内のタイムゾーンの指定////////////////////////////////
Time.zone = 'Tokyo'
ActiveRecord::Base.default_timezone = :local
enable :sessions

# ////////////////////////////////////////////////////////////////
module Websockettest2
  class App < Sinatra::Base
    get '/' do
      erb :index
    end
  end
end

helpers do
  def current_user
    if session[:user]
	User.find(session[:user])
    end
  end
end
# ////////////////////////////////デフォルト参照////////////////////////////////
get '/chat' do
  if User.find_by id: session[:user]
    erb :chat
  else
    erb :index
  end
end

get '/tl' do
  if User.find_by id: session[:user]
    erb :tl
  else
    erb :index
  end
end

get '/' do
  erb :index
end

get '/room' do
  if User.find_by id: session[:user]
    erb :room
  else
    erb :index
  end
end

# ////////////////////////////////ルーム作成////////////////////////////////
get '/create_room' do
  if User.find_by id: session[:user]
    erb :create_room
  else
    erb :index
  end
end

post '/create_room' do
  if range = params[:range]
    range.each do |i|#ここで"true"をtrueへ変換
      range = i
    end
  else
    range = false
  end

  if admin = params[:admin]
    admin = true
  else
    admin = false
  end

  room = Room.new(
  name: params[:title],
  range: range,
  room_admin: admin
  )

  if room.save
    erb :room
  else
    @message = "ルーム作成に失敗しました"
    erb :message
  end
end

# ////////////////////////////////ルームリスト表示////////////////////////////////
get '/my_room_list' do
  if User.find_by id: session[:user]
    @list_all = Room.where(range: true)
    erb :my_room_list
  else
    erb :index
  end
end

# ////////////////////////////////user_search////////////////////////////////
get '/search' do
  if User.where("user_name like '%#{params[:search]}%'").exists?
    if Room.where("name like '%#{params[:search]}'").exists?
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @search_lists = Room.where("name like '%#{params[:search]}'")
      erb :user_list
    else 
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @search_users = false
      erb :user_list
    end
  elsif Room.where("name like '%#{params[:search]}'").exists?
    if User.where("user_name like '%#{params[:search]}%'").exists?
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @search_lists = Room.where("name like '%#{params[:search]}'")
      erb :user_list
    else 
      @search_lists = Room.where("name like '%#{params[:search]}'")
      @search_lists = false
      erb :user_list
    end
  else
    @message = "存在しません"
    erb :message
  end
end
# ////////////////////////////////ルームの削除////////////////////////////////
get '/delete/:id' do
  room = Room.delete(params[:id])
  if room
    redirect 'my_room_list'
  else
    @messeage = "内部サーバーエラー"
    erb :messeage
  end
end

# ////////////////////////////////パブリックルーム////////////////////////////////
get '/public_room' do
  if User.find_by id: session[:user]
    erb :my_room_list
  else
    erb :index
  end
end
# ////////////////////////////////フレンド機能設定////////////////////////////////
def friends
  p 'user = User.find_by :session[:user]'
  p user = User.find_by_id(session[:user])
  @my_user = user
  # @my_friends = user.friends
  erb :friends
end

get '/friends' do
  if User.find_by id: session[:user]
    erb :friends
    friends
  else
    erb :index
  end
end
# ////////////////////////////////チャット送信////////////////////////////////
post '/chat' do
  p talk = Talk.new(
    talk: params[:chat],
    user_name: session[:user]
  )
  if p talk.save
    redirect '/room'
  else
    redirect '/room'
  end
end
# ////////////////////////////////サインイン////////////////////////////////
get '/signin' do
  erb :room if User.find_by id: session[:user]
  erb :index #=> めんどくさいから、後でSigninを作ったら変更しよう。。。（＾ω＾ ≡ ＾ω＾）おっおっおっ
end

post '/signin' do
  if user = User.find_by_mail(params[:name]) # メールアドレスが存在するか確認する
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      @user = user.user_name
      erb :room
    else # もし合っていなかったら以下実行
      @user_true = true
      erb :index
    end
  elsif user = User.find_by_user_name(params[:name])
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      @user = user.user_name
      erb :room
    else # もし合っていなかったら以下実行
      @user_name_true = true
      erb :index
    end
  else
    @t = true
    erb :index
  end
end
# ////////////////////////////////サインアウト////////////////////////////////
get '/logout' do
  session[:user] = nil
  redirect '/'
end

# ////////////////////////////////予約変更////////////////////////////////
get '/edit/:id' do
  @message = 'このページは閲覧できません'
  erb :message
end
post '/edit/:id' do
  @users = User.find(params[:id])
  erb :edit
end

# ////////////////////////////////予約変更保存////////////////////////////////

post '/renew/:id' do
  user = User.find(params[:id])
  if user && user.authenticate(params[:password])
    unless User.where(user_name: params[:user_name]).exists?
      session[:user] = user.id
      user.update(name:   params[:name],
                  user_name:    params[:user_name],
                  mail:    params[:mail],
                  age: params[:age],
                  introduction: params[:introduction]
                 )
      redirect '/room'
      else
        @message = 'このユーザー名は使用できません'
        erb :message
    end
  else
    @message = 'パスワードが異なります'
    erb :message
  end
end
# ////////////////////////////////ここからメール本確認////////////////////////////////
get '/send_mail' do
  erb :send_mail
end

post '/send_mail' do
  email = params[:email]
  mail_check = User.where(mail: email).exists? # 入力したメールアドレスがあるか確認
  if mail_check # 入力したメールアドレスがあれば@messageを表示
    @message = "入力されたメールアドレスは登録済みです。"
    erb :index
  else # 入力したメールアドレスがなければ↓を実行
    random = SecureRandom.uuid # 乱数で暗号を作成
    token = Token.new( # 暗号とメールアドレスをDBに作成
      token: random,
      address: params[:email],
      expired_at: 24.hours.since
    )
    if token.save # 暗号とメールアドレスをDBに作成できれば↓を実行
      p email_secret = Base64.encode64(random) # 暗号を暗号化する

      xyz = 'localhost:4567'

      Pony.mail(
        to: email,
        body: "
               アカウントに登録していただきありがとうございます。まだ、
               アカウント登録は完了していませんので、
               http://#{xyz}/signup/#{email_secret}
               にアクセスして、本登録を行って下さい",
        subject: "仮登録が完了しました",
        via: :smtp,
        via_options: {
          enable_starttls_auto: true,
          address: 'smtp.gmail.com',
          port: '587',
          user_name: 'nagisa20000014',
          password: 'yriqalcacichqxir',
          authentication: :plain,
          domain: 'gmail.com'
        }
      )

      redirect '/account'
    else # 保存に失敗したら↓を実行
      @message = '不明なエラーが発生しました'
      erb :message
    end
  end
end

get '/signup/:email_secret' do
  secret = params[:email_secret] # URLの暗号の暗号を取得
  secret_mail = Base64.decode64(secret) # 暗号の暗号を解読
  @mail = Token.find_by_token(secret_mail).address # 暗号からメールアドレスを取得
  token = Token.find_by_token(secret_mail) # 暗号がDBにあるか確認

  if token && token.expired_at > Time.now # 暗号がDBにあれば時間外か確認
    token.update(expired_at: Time.now)# DBが時間内であれば時間外にして
    erb :sign_up # フォームを表示する
  else # DBが時間外なら↓を実行
    @message = "入力されたメールアドレスは本登録が完了していいるかURLの有効期限が切れています"
    erb :message
  end
end
# ////////////////////////////////アカウント作成////////////////////////////////
post '/signup' do
  unless User.where(user_name: params[:user_name]).exists?
    @user = User.new(
      name: params[:name],
      user_name: params[:user_name],
      mail: params[:mail],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
    if @user.save
      session[:user] = @user.id unless @user.nil?
      redirect '/room'
    else
      @message = '不明なエラーが発生しました'
      erb :message
    end
  else
    @message = 'すでに使われているUserNameです'
    erb :message
  end
end

get '/account' do
  erb :account
end
