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
require 'SecureRandom'
use Rack::Session::Cookie
# ////////////////////////////////サイト内のタイムゾーンの指定////////////////////////////////
Time.zone = 'Tokyo'
ActiveRecord::Base.default_timezone = :local
enable :sessions

# ////////////////////////////////////////////////////////////////
# module Websockettest2
#   class App < Sinatra::Base
#     get '/' do
#       erb :index
#     end
#   end
# end

helpers do
  def current_user
    if session[:user]
      User.find(session[:user])
    end
  end
end
# ////////////////////////////////デフォルト参照////////////////////////////////
get '/chat' do
  if session[:user]
    erb :chat
  else
    erb :index
  end
end

get '/tl' do
  if session[:user]
    erb :tl
  else
    erb :index
  end
end

get '/' do
  erb :index
end

get '/room' do
  if session[:user]
    @list_all = User.find(session[:user]).rooms
    erb :room
  else
    erb :index
  end
end

# ////////////////////////////////ルーム作成////////////////////////////////
get '/create_room' do
  if session[:user]
    erb :create_room
  else
    erb :index
  end
end

post '/create_room' do

  unless Room.where(name: params[:title]).exists?#作ろうとしたRoom_Nameがすでに存在するか？
    if range = params[:range]
      range.each do |i|#ここで"true"をtrueへ変換
        range = i
      end
    end

    if params[:admin]#FormのAdminチェックボックスにチェックが付いていたら以下を実行
      admin = true
    else#FormのAdminチェックボックスにチェックが付いていなかったら以下を実行
      admin = false
    end

    if range == "true"#公開範囲がパブリックだったら以下を実行
      room = Room.new(
        admin: admin,
        name: params[:title],
        range: range
      )
      if room.save
        @room = Room.find_by_name(params[:title]).id
        Userroom.create(room_id: @room, user_id: session[:user], status: 1)
        redirect "/join_room/#{@room}"
      else
        @message = "ルーム作成に失敗しました"
        erb :message
      end
    else#公開範囲がプライベートだったら以下を実行
      url = SecureRandom.uuid#URLがRoomIDではない乱数URLを作成
      room = Room.new(
        admin: admin,
        name: params[:title],
        range: range,
        token: url
      )
      if room.save#保存が成功したら以下を実行
        @room = Room.find_by_name(params[:title]).id#Roomの名前からRoomIDを持ってくる
        Userroom.create(room_id: @room, user_id: session[:user], status: 1)
        redirect "/join_private_room/#{url}"#作成したRoomに飛ばす
      else#Room作成が失敗した場合
        @message = "ルーム作成に失敗しました"
        erb :message
      end
    end
  else#もし存在したRoom_Nameを使おうとした場合errorを表示させる
    @true = true #=>このルーム名はすでに存在しているため作成することができません 
    erb :create_room
  end
end

# ////////////////////////////////ルームリスト表示////////////////////////////////
get '/my_room_list' do
  if session[:user]
    #Room.find(Room.pluck(:id).shuffle[0..4])
    @list_all = Room.where(range: true)
    erb :my_room_list
  else
    erb :index
  end
end

# ////////////////////////////////Join_Room////////////////////////////////
get '/join_room/:id' do
  if session[:user]
  user = Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id]))
  check = Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id])).exists?

  user.each do |i|
    user = i
  end

  if check#選択したRoomに以前入ったことがあれば以下を実行
    unless user.block?#選択したRoomからBlockされいなければ以下を実行
      if Room.where(id: params[:id], range: true).exists?#選択したRoomがパブリックルームだったら以下を実行
        @room = Room.find(params[:id])#idからRoomを探す
        erb :talk_room
      elsif Userroom.where(user_id: session[:user],room_id: params[:id]).exists?#一度は行ったルームにuuidなしで入れるようにする
        @room = Room.find(params[:id])
        erb :talk_room
      else
        @message = "このルームはプライベートルームなため閲覧できません"
        erb :message
      end
    else
      @message = "このルームからはブロックされています"
      erb :message
    end
  else#選択したRoomに以前入ったことがなければ以下を実行
    if Room.where(id: params[:id], admin: true, range: true).exists?
      @room = Room.find(params[:id])
      Userroom.create(room: @room, user_id: session[:user])
      erb :talk_room
    elsif Room.where(id: params[:id], admin: false, range: true).exists?
      @room = Room.find(params[:id])
      Userroom.create(room: @room, user_id: session[:user], status: 1)
      erb :talk_room
    else
        @message = "このルームはプライベートルームなため閲覧できません"
        erb :message
    end
  end
  else
    erb :index
  end
end

get '/join_private_room/:id' do
  if session[:user]
    if Room.where(token: params[:id]).exists?
      @room = Room.find_by_token(params[:id])
      Userroom.create(room: @room, user_id: session[:user])
      erb :talk_room 
    else
      @message = "ルームを見つけることができませんでした"
      erb :message
    end
  else
    erb :index
  end
end
# ////////////////////////////////Logout_Room////////////////////////////////
get '/room_logout/:id' do
  room = Userroom.find(params[:id])
  room.update(user_id: nil)
  @list_all = Room.where(range: true)
  redirect'/my_room_list'
end
# ////////////////////////////////edit_Room////////////////////////////////
get '/room_edit/:id' do
  if session[:user]
    userroom = Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id]))

    userroom.each do |i|
      userroom = i
    end

    if userroom.admin?
      @room = Room.find(params[:id])
      erb :room_edit
    elsif Room.where(id: params[:id],admin: false).exists?
      @room = Room.find(params[:id])
      erb :room_edit
    else
      @message = "設定をいじる権限がありません"
      erb :message
    end
  else
    erb :index
  end
end

post '/room_renew/:id' do
  room = Room.find(params[:id])
  room.update(name: params[:name])
  @save_true = true
  redirect"/room_edit/#{params[:id]}"
end

post '/room_delete/:id' do
  Room.destroy(params[:id])

  chat = Chat.where(room_id: params[:id])
  chat.each do |chat|
    chat.delete
  end

  room = Userroom.where(room_id: params[:id])
  room.each do |room|
    room.delete
  end

  redirect'/room'
end
post '/join_member_delete/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id],room_id: params[:room_id])
  userroom.each do |i|
    userroom = i
  end
  userroom.block!
  redirect "join_room/#{params[:room_id]}"
end

post '/join_member_admin/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id],room_id: params[:room_id])
  userroom.each do |i|
    userroom = i
  end
  userroom.admin!
  redirect "join_room/#{params[:room_id]}"
end
post '/join_member_normal/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id],room_id: params[:room_id])
  userroom.each do |i|
    userroom = i
  end
  userroom.normal!
  redirect "join_room/#{params[:room_id]}"
end

# ////////////////////////////////Create_chat////////////////////////////////
post '/chat' do
  chat = params[:chat]
  p user = User.find(session[:user])
  id = params[:room_id]
  Room.find(id).chats.create(user: user, text: chat)
  redirect "/join_room/#{id}"
end

# ////////////////////////////////user_search////////////////////////////////
get '/search' do
  if User.where("user_name like '%#{params[:search]}%'").exists?
    if Room.where("name like '%#{params[:search]}%'").exists?
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @search_lists = Room.where("name like '%#{params[:search]}%'")
      @true_lists = true
      @true_users = true
      erb :user_list
    else 
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @true_users = true
      @true_lists = false
      erb :user_list
    end
  elsif Room.where("name like '%#{params[:search]}%'").exists?
    if User.where("user_name like '%#{params[:search]}%'").exists?
      @search_users = User.where("user_name like '%#{params[:search]}%'")
      @search_lists = Room.where("name like '%#{params[:search]}%'")
      @true_users = true
      @true_lists = false
      erb :user_list
    else 
      @search_lists = Room.where("name like '%#{params[:search]}%'")
      @true_users = false
      @true_lists = true
      erb :user_list
    end
  else
    @message = "ユーザーとルームが存在しません"
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
  if session[:user]
    erb :room 
  else
    erb :index #=> めんどくさいから、後でSigninを作ったら変更しよう。。。（＾ω＾ ≡ ＾ω＾）おっおっおっ
  end
end

post '/signin' do
  if user = User.find_by_mail(params[:name]) # メールアドレスが存在するか確認する
    #MailAddress
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      session[:user_name] = user.user_name
      @user = user.user_name
      @list_all = User.find(session[:user]).rooms
      erb :room
    else # もし合っていなかったら以下実行
      @user_true = true
      erb :index
    end
    #普通のUser_name
  elsif user = User.find_by_user_name(params[:name])
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      session[:user_name] = user.user_name
      @user = user.user_name
      @list_all = User.find(session[:user]).rooms
      erb :room
    else # もし合っていなかったら以下実行
      @user_true = true
      erb :index
    end
    #@のついたUser_name
  elsif cut = params[:name]
    if cut.slice!("@")
      if user = User.find_by_user_name(cut)
        if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
          session[:user] = user.id # セッションにユーザーデータを保存する
          session[:user_name] = user.user_name
          @user = user.user_name
          @list_all = User.find(session[:user]).rooms
          erb :room
        else # もし合っていなかったら以下実行
          @user_true = true
          erb :index
        end
      else
        @user_true = true
        @message = "意味ワカンねえええ"
        erb :message
      end
    end
  else
    @message = "erraaaaaaaa"
    erb :message
  end
end
# ////////////////////////////////サインアウト////////////////////////////////
get '/logout' do
  session[:user] = nil
  redirect '/'
end

# ////////////////////////////////予約変更////////////////////////////////
get '/edit/:id' do 
  if "#{session[:user]}" == params[:id]
    @users = User.find(params[:id])
    erb :edit
  else
    @message = 'このページは閲覧できません'
    erb :message
  end
end

# ////////////////////////////////個人情報設定変更////////////////////////////////

post '/renew/:id' do
  user = User.find(params[:id])
  if user && user.authenticate(params[:password])#入力されたパスワードが合っていれば以下を実行
    if p user.user_name == params[:user_name]#入力されたUsesr_nameが以前と同じものなら以下を実行
      session[:user] = user.id
      user.update(#↓User_Nameを変更しないアップデート
        name:   params[:name],
        mail:    params[:mail],
        age: params[:age],
        introduction: params[:introduction]
      )
      redirect '/room'
    else#入力されたUser_Nameが以前と違うものなら以下を実行
      unless User.where(user_name: params[:user_name]).exists?#入力されたUser＿Nameがすでに存在していなければ以下を実行
        session[:user] = user.id
        user.update(#↓User_Nameを変更するアップデート
          name:   params[:name],
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
    @user_name_true = "入力されたメールアドレスは登録済みです。"
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
