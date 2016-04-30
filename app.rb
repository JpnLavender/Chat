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
require 'padrino-helpers'
require 'kaminari/sinatra'
require 'json'
# require 'sinatra-websocket'

set :server, 'thin'
set :sockets, Hash.new { |h, k| h[k] = [] }

set :erb, layout_options: { layout: true }
# set :layout, true
helpers Kaminari::Helpers::SinatraHelpers

set :locales, Dir['locales/*.yml']
I18n.config.available_locales = :en

use Rack::Session::Cookie
enable :sessions
# ////////////////////////////////サイト内のタイムゾーンの指定////////////////////////////////
Time.zone = 'Tokyo'
ActiveRecord::Base.default_timezone = :local

# ////////////////////////////////////////////////////////////////
helpers do
  def current_user
    User.find(session[:user]) if User.where(id: session[:user]).exists?
  end
end

not_found do
  @message = "404 not found ページが見つかりませんでした"
  erb :message
end

error do
  @message = 'SystemServerError'
  erb :message
end

def error
  @message = "内部サーバーエラー"
  erb :message
end

def alert
  if User.where(session[:user])[0].alerts.exists?
    @alert_count = User.find(session[:user]).alerts # ユーザーに紐付いてる通知を全て持ってくる(layout.erbのHeader用)
  end
end

def logout
  session[:user] = nil
  redirect '/'
end

# ////////////////////////////////デフォルト参照////////////////////////////////

get '/' do
  erb :index, layout: :layout
end
get '/tl' do
  if User.where(id: session[:user]).exists?
    alert
    erb :tl, layout: :layout
  else
    erb :index, layout: :layout
  end
end
get '/room' do
  if User.where(id: session[:user]).exists?
    @list_all = User.find(session[:user]).rooms.page(params[:page])
    alert
    erb :room, layout: :layout
  else
    erb :index, layout: :layout
  end
end
# ////////////////////////////////お知らせ通知////////////////////////////////
get '/alert' do
  if User.where(id: session[:user]).exists?
    @alert_count = User.find(session[:user]) # ユーザーに紐付いてる通知を全て持ってくる(layout.erbのHeader用)
    if @alert_count.alerts.exists? || Alert.where(user: @alert_count, reading: false).exists?
      @alert_count.alerts.each do |s|
        p as = Alert.where(user: @alert_count, reading: false)
        as.each do |a|
					a.update(reading: true)
        end
      end
    end
    erb :alert, layout: :layout
  else
    alert
    redirect '/room'
  end
end
# ////////////////////////////////ルーム作成////////////////////////////////
get '/create_room' do
  if User.where(id: session[:user]).exists?
    alert
    erb :create_room, layout: :layout
  else
    alert
    erb :index, layout: :layout
  end
end

post '/create_room' do
  unless Room.where(name: params[:title]).exists? # 作ろうとしたRoom_Nameがすでに存在するか？
    if range = params[:range]
      range = range[0]
    end

    admin = if params[:admin] # FormのAdminチェックボックスにチェックが付いていたら以下を実行
              true
            else # FormのAdminチェックボックスにチェックが付いていなかったら以下を実行
              false
            end

    if range == 'true' # 公開範囲がパブリックだったら以下を実行
      room = Room.new(admin: admin, name: params[:title], range: range )
      if room.save
        @room = Room.where(name: params[:title]).page(params[:page])
        Userroom.create(room_id: @room[0].id, user_id: session[:user], status: 1)
        alert
        redirect "/join_room/#{@room[0].id}"
      else
        @message = "ルーム作成に失敗しました"
        erb :message, layout: :layout
      end
    else # 公開範囲がプライベートだったら以下を実行
      url = SecureRandom.uuid # URLがRoomIDではない乱数URLを作成
       room = Room.new(
        admin: admin,
        name: params[:title],
        range: range,
        token: url
      )
      if room.save # 保存が成功したら以下を実行
        @room = Room.find_by_name(params[:title])
        Userroom.create(room_id: @room.id, user_id: session[:user], status: 1)
        redirect "/join_private_room/#{url}" # 作成したRoomに飛ばす
      else # Room作成が失敗した場合
        @message = "ルーム作成に失敗しました"
        alert
        erb :message, layout: :layout
      end
    end
  else # もし存在したRoom_Nameを使おうとした場合errorを表示させる
    @true = true #=>このルーム名はすでに存在しているため作成することができません
    alert
    erb :create_room, layout: :layout
  end
end

# ////////////////////////////////favoroom///////////////////////////////
get '/favoroom' do 
	erb :favo_room_list, layout: :layout 
end
post '/favoroom' do
	Favoroom.create(room_id: params[:room_id],user_id: params[:user_id])
	redirect 'my_room_list'
end
post '/unfavoroom' do
	Favoroom.where(room_id: params[:room_id],user_id: params[:user_id]).each do |favo|
		favo.delete
	end
	redirect 'my_room_list'
end

# ////////////////////////////////ルームリスト表示////////////////////////////////
get '/my_room_list' do
  if User.where(id: session[:user]).exists?
    @list_all = Room.where(range: true).page(params[:page])
    alert
    erb :my_room_list, layout: :layout
  else
    alert
    erb :index, layout: :layout
  end
end

# ////////////////////////////////Join_Room////////////////////////////////
get '/join_room/:id' do
	if Room.where(id: params[:id]).exists?
		if User.where(id: session[:user]).exists?
			@id = params[:id]
			users = Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id]))
			user = users[0]
			if !request.websocket?
				if User.where(id: session[:user]).exists? # Userが存在するか
					name = User.find(session[:user]).name # セッションからRoomに入ろうとしてるUser_nameを取得する
					rooms = Room.where(id: params[:id]) # URLからRoomを探す
					room = rooms[0].userrooms # RoomからUserRoomを探す
					if Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id])).exists? # #選択したRoomに以前入ったことがあれば以下を実行
						unless user.block? # 選択したRoomからBlockされいなければ以下を実行
							if Room.where(id: params[:id], range: true).exists? # 選択したRoomがパブリックルームだったら以下を実行
								@room = Room.where(id: params[:id]).page(params[:page]) # idからRoomを探す
								alert
								erb :talk_room, layout: :layout
							elsif Userroom.where(user_id: session[:user], room_id: params[:id]).exists? # 一度は行ったルームにuuidなしで入れるようにする
								@room = Room.where(id: params[:id]).page(params[:page])
								alert
								erb :talk_room, layout: :layout
							else
								@message = "このルームはプライベートルームなため閲覧できません"
								alert
								erb :message, layout: :layout
							end
						else
							@message = "このルームからはブロックされています"
							alert
							erb :message, layout: :layout
						end
					else # 選択したRoomに以前入ったことがなければ以下を実行
						if Room.where(id: params[:id], admin: true, range: true).exists? # AdminがONになってるRoom
							@room = Room.where(id: params[:id]).page(params[:page])
							rooms[0].users.each do |user|
								Alert.create(title: "#{name}が『#{rooms[0].name}』に入室しました", reading: false, user_id: user.id, url: "join_room/#{params[:id]}")
							end
							Userroom.create(room_id: @room[0].id, user_id: session[:user])
							alert
							erb :talk_room, layout: :layout
						elsif Room.where(id: params[:id], admin: false, range: true).exists? # AdminがOFFになってるRoom
							@room = Room.where(id: params[:id]).page(params[:page])
							rooms[0].users.each do |user|
								Alert.create(title: "#{name}が『#{rooms[0].name}』に入室しました", reading: false, user_id: user.id, url: "join_room/#{params[:id]}")
							end
							Userroom.create(room: @room, user_id: session[:user], status: 1)
							alert
							erb :talk_room, layout: :layout
						else
							@message = "このルームはプライベートルームなため閲覧できません"
							alert
							erb :message, layout: :layout
						end
					end
				else
					erb :index, layout: :layout
				end
			else
				us = User.find(session[:user])
				request.websocket do |ws|
					ws.onopen do
						# ws.send("Hello World!")
						settings.sockets[@id] << ws
					end
					ws.onmessage do |msg|
						EM.next_tick  do
							settings.sockets[@id].each do |s|
								s.send({ user: { id: us.id, name: us.name, color: us.color }, body: msg }.to_json)
							end
							# s.send({ body }.to_json)
							Room.find(@id).chats.create(user: us, text: msg)
						end
					end
					ws.onclose do
						warn('websocket closed')
						settings.sockets[@id].delete(ws)
					end
				end
			end
		else
			redirect '/'
		end
	else
		@message = 'ルームが存在しません'
		erb :message , layout: :layout 
	end
end

get '/join_private_room/:id' do
  search = Room.where(token: params[:id])
  if User.where(id: session[:user]).exists?
    if search.exists?
      @room = search
      Userroom.create(room: @room[0], user_id: session[:user])
      alert
      erb :talk_room, layout: :layout
    else
      @message = "ルームを見つけることができませんでした"
      alert
      erb :message, layout: :layout
    end
  else
    erb :index, layout: :layout
  end
end
# ////////////////////////////////Logout_Room////////////////////////////////
get '/room_logout/:id' do
  if User.where(id: session[:user]).exists?
    room = Userroom.find(params[:id])
    room[:user_id] = nil
    # @list_all = Room.where(range: true).page(params[:page])
    alert
    redirect'/my_room_list'
  else
    erb :index, layout: :layout
  end
end
# ////////////////////////////////edit_Room////////////////////////////////
get '/room_edit/:id' do
	if Room.where(id: params[:id]).exists?
		if User.where(id: session[:user]).exists?
    userroom = Userroom.where(user: User.find(session[:user]), room: Room.find(params[:id]))
    p userroom
    if userroom[0].admin?
      @room = Room.where(id: params[:id]).page(params[:page])
      alert
      erb :room_edit, layout: :layout
    elsif Room.where(id: params[:id], admin: false).exists?
      @room = Room.where(id: params[:id]).page(params[:page])
      alert
    else
      @message = "設定をいじる権限がありません"
      alert
      erb :message, layout: :layout
    end
  else
    erb :index, layout: :layout
  end
	else
		@message = 'ルームが存在しません'
    erb :index, layout: :layout
	end
end

post '/room_renew/:id' do
  room = Room.find(params[:id])
  room[:name] = params[:name]
  alert
  redirect"/room_edit/#{params[:id]}"
end

post '/room_delete/:id' do
  Room.destroy(params[:id])

  chat = Chat.where(room_id: params[:id])
  chat = chat[0]
  chat.delete

  room = Userroom.where(room_id: params[:id])
  room = room[0]
  room.delete

  alert
  redirect'/room'
end
post '/join_member_delete/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id], room_id: params[:room_id])
  userroom[0].block!
  alert
  redirect "room_edit/#{params[:room_id]}"
end

post '/join_member_admin/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id], room_id: params[:room_id])
  userroom[0].admin!
  alert
  redirect "room_edit/#{params[:room_id]}"
end
post '/join_member_normal/:user_id/:room_id' do
  userroom = Userroom.where(user_id: params[:user_id], room_id: params[:room_id])
  userroom[0].normal!
  alert
  redirect "room_edit/#{params[:room_id]}"
end

# ////////////////////////////////send_chat////////////////////////////////
post '/chat' do
  user = User.find(session[:user])
  id = params[:room_id]
  Room.find(id).chats.create(user: user, text: params[:chat])
  alert
  redirect "/join_room/#{id}"
end

get '/application.js' do
  content_type :js
  @scheme = ENV['RACK_ENV'] == 'production' ? 'wss://' : 'ws://'
  erb :"application.js"
end
# ////////////////////////////////Ramdom_Send////////////////////////////////
post '/random_send' do
  room_id = Room.find(params[:room_id])
  user = User.find(session[:user])
  p "Randomテスト"
  p random = room_id.users.sample.id
  Room.find(room_id.id).chats.create(user: user, text: params[:chat], form_user: random)
  alert
  redirect "/join_room/#{room_id.id}"
end

# ////////////////////////////////user_search////////////////////////////////
get '/search' do
  if User.where(session[:user]).exists?
    room = Room.where("name like '%#{params[:search]}%'")
    # UserNameが発見できてなおかつRoomNameも発見できた場合
    if User.where("user_name like '%#{params[:search]}%'").exists?
      if room.where(range: true).exists?
        @search_users = User.where("user_name like '%#{params[:search]}%'")
        @search_lists = room.where(range: true)
        @true_lists , @true_users = true ,true
        alert
        erb :search, layout: :layout
      else # UserNameは発見できたけどRoomNameが発見できなかった場合
        @search_users = User.where("user_name like '%#{params[:search]}%'")
        @true_users, @true_lists = true, false
        alert
        erb :search, layout: :layout
      end
      # RoonNameが発見できたけどUserNameが発見できなかった場合
    elsif room.where(range: true).exists?
      if User.where("user_name like '%#{params[:search]}%'").exists?
        @search_users = User.where("user_name like '%#{params[:search]}%'")
        @search_lists = room.where(range: true)
        @true_users, @true_lists = true, false
        alert
        erb :search, layout: :layout
      else
        @search_lists = room.where(range: true)
        @true_users, @true_lists = false, true
        alert
        erb :search, layout: :layout
      end
    else
      @message = "ユーザーとルームが存在しません"
      alert
      erb :message, layout: :layout
    end
  else
    erb :index, lsyout: :layout
  end
end

# ////////////////////////////////////////////////////////////////
# Friend
# ////////////////////////////////////////////////////////////////
post '/follow/:id' do
  friend = Friend.new(user_id: session[:user], friend_id: params[:id])
  if friend.save
    Alert.create(title: "#{User.find(session[:user]).name}があなたを友達登録しました", user_id: params[:id], status: 1)
    alert
    redirect '/room'
  else
    error
  end
end

post '/add_friend/:id' do
  if Friend.where(user_id: session[:user], friend_id: params[:id], status: 0).exists?
    friend = Friend.where(user_id: session[:user], friend_id: params[:id], status: 0)
    friend.each do |friend|
      if friend.friend!
        redirect '/alert'
      else
        redirect '/alert'
      end
    end
  end
end
post '/delete_friend/:id' do
  if Friend.where(user_id: session[:user], friend_id: params[:id], status: 0).exists?
    friend = Friend.where(user_id: session[:user], friend_id: params[:id], status: 0)
    if friend.block!
      redirect '/alert'
    else
      redirect '/alert'
    end
  end
end
# ////////////////////////////////ルームの削除////////////////////////////////
get '/delete/:id' do
  room = Room.delete(params[:id])
  if room
    alert
    redirect 'my_room_list'
  else
    @messeage = "内部サーバーエラー"
    alert
    erb :messeage, layout: :layout
  end
end

# ////////////////////////////////パブリックルーム////////////////////////////////
get '/public_room' do
  if User.find_by id: session[:user]
    alert
    erb :my_room_list, layout: :layout
  else
    alert
    erb :index, layout: :layout
  end
end

# ////////////////////////////////UserAccount////////////////////////////////
get '/@/:user_name/:select' do
  if User.where(user_name: params[:user_name]).exists?
    @user = User.where(user_name: params[:user_name])
    if params[:select] == 'joinroom'
      @joinroom ,@friend ,@timeline = true, false, false
      erb :select_user, layout: :layout
    elsif params[:select] == 'friend'
      @friend, @joinroom , @timeline = true, false ,false
      erb :select_user, layout: :layout
    elsif params[:select] == 'timeline'
      @timeline , @joinroom , @friend  = true, false, false
      erb :select_user, layout: :layout
    end
  else
    @message = "選択されたユーザーが存在しません"
    erb :messeage, layout: :layout
  end
end

# ////////////////////////////////フレンド機能設定////////////////////////////////

get '/friends' do
  if User.find_by id: session[:user]
    user = User.find_by_id(session[:user])
    @my_friends = user.friends # ユーザーと友達になってるユーザー一覧を持ってくる
    alert
    erb :friends, layout: :layout
  else
    erb :index, layout: :layout
  end
end

get '/create_friend_room/:friend_id' do
  # friend_idはテーブルid
  friend = Friend.find(params[:friend_id])
  unless p Userroom.where(user_id: [friend.user_id, friend.friend_id]).group(:room_id).having('count(*) = 2').exists?
    friend = Friend.find(params[:friend_id]) # Friendのテーブルを探す
    user = User.find(friend.friend_id) # フレンドのテーブルの中に入っている友達のIDを持ってくる
    name = user.name.to_s + '&' + friend.user.name.to_s # RoomNameを作る
    # if Room.where(name: name).exists?
    room = Room.new(admin: false, name: name, range: false)
    if room.save
      @room = Room.where(name: name)
      Userroom.create(room: @room, user_id: user.id)
      Userroom.create(room: @room, user_id: session[:user])
      alert
      redirect "/join_room/#{@room.id}"
    else
      error
    end
  else
    friend_room = Userroom.where(user_id: [friend.user_id, friend.friend_id]).group(:room_id).having('count(*) = 2')
    alert
    friend_room.each do |room|
      @room = Room.where(id: room.room_id).page(params[:page])
      alert
      redirect "join_room/#{room.room_id}"
    end
  end
end

post '/alert_delete/:id' do
  alert
  alert = Alert.find(params[:id])
  alert.delete
  redirect '/alert'
end
# ////////////////////////////////サインイン////////////////////////////////
get '/signin' do
  if User.where(id: session[:user]).exists?
    alert
    erb :room, layout: :layout
  else
    erb :sign_in, layout: :layout #=> めんどくさいから、後でSigninを作ったら変更しよう。。。（＾ω＾ ≡ ＾ω＾）おっおっおっ
  end
end

post '/signin' do
  if user = User.find_by_mail(params[:name]) # メールアドレスが存在するか確認する
    # MailAddress
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      session[:user_name] = user.user_name
      @user = user.user_name
      @list_all = User.find(session[:user]).rooms.page(params[:page])
      alert
      erb :room, layout: :layout
    else # もし合っていなかったら以下実行
      @user_true = true
      alert
      erb :index, layout: :layout
    end
    # 普通のUser_name
  elsif user = User.find_by_user_name(params[:name])
    if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
      session[:user] = user.id # セッションにユーザーデータを保存する
      session[:user_name] = user.user_name
      @user = user.user_name
      @list_all = User.find(session[:user]).rooms.page(params[:page])
      alert
      erb :room, layout: :layout
    else # もし合っていなかったら以下実行
      @user_true = true
      alert
      erb :index, layout: :layout
    end
    # @のついたUser_name
  elsif cut = params[:name]
    if cut.slice!('@')
      if user = User.find_by_user_name(cut)
        if user && user.authenticate(params[:password]) # メールアドレスが有りなおかつ入力されたパスワードがあっているか確認する
          session[:user] = user.id # セッションにユーザーデータを保存する
          session[:user_name] = user.user_name
          @user = user.user_name
          @list_all = User.find(session[:user]).rooms.page(params[:page])
          alert
          erb :room, layout: :layout
        else # もし合っていなかったら以下実行
          @user_true = true
          alert
          erb :index, layout: :layout
        end
      else
        @user_true = true
        @message = "不明なエラーが発生しました"
        alert
        erb :message, layout: :layout
      end
    end
  else
    @message = 'erraaaaaaaa'
    alert
    erb :message, layout: :layout
  end
end
# ////////////////////////////////サインアウト////////////////////////////////
get '/logout' do
  session[:user] = nil
  redirect '/'
end

# ////////////////////////////////予約変更////////////////////////////////
get '/edit' do
  if User.where(id: session[:user]).exists?
    @users = User.find(session[:user])
    alert
    erb :edit, layout: :layout
  else
    @message = 'このページは閲覧できません'
    alert
    erb :message, layout: :layout
  end
end

# ////////////////////////////////個人情報設定変更////////////////////////////////

post '/renew/:id' do
  user = User.find(params[:id])
  if user && user.authenticate(params[:password]) # 入力されたパスワードが合っていれば以下を実行
    if p user.user_name == params[:user_name] # 入力されたUsesr_nameが以前と同じものなら以下を実行
      session[:user] = user.id
      user.update( # ↓User_Nameを変更しないアップデート
        name:   params[:name],
        mail:    params[:mail],
        color: params[:color],
        age: params[:age],
        introduction: params[:introduction]
      )
      alert
      redirect '/room'
    else # 入力されたUser_Nameが以前と違うものなら以下を実行
      unless User.where(user_name: params[:user_name]).exists? # 入力されたUser＿Nameがすでに存在していなければ以下を実行
        session[:user] = user.id
        user.update( # ↓User_Nameを変更するアップデート
          name:   params[:name],
          user_name:    params[:user_name],
          mail:    params[:mail],
          age: params[:age],
          color: params[:color],
          introduction: params[:introduction]
        )
        redirect '/room'
      else
        @message = 'このユーザー名は使用できません'
        alert
        erb :message, layout: :layout
      end
    end
  else
    @true =  true
    @users = User.find(session[:user])
    alert
    erb :edit, layout: :layout
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
    erb :index, layout: :layout
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
      alert
      erb :message, layout: :layout
    end
  end
end

get '/signup/:secret_mail' do
	number = Base64.decode64(params[:secret_mail]) # 暗号の暗号を解読
	token =  Token.find_by_token(number)
	if token && token.expired_at > Time.now # 暗号がDBにあれば時間外か確認
		@secret_mail_id = params[:secret_mail]
		number = Base64.decode64(params[:secret_mail]) # 暗号の暗号を解読
		@mail = Token.find_by_token(number).address
		erb :sign_up, layout: :layout # フォームを表示する
	else # DBが時間外なら↓を実行
		@message = "入力されたメールアドレスは本登録が完了していいるかURLの有効期限が切れています"
		erb :message, layout: :layout
	end
end
# ////////////////////////////////アカウント作成////////////////////////////////
post '/signup' do
	unless User.where(user_name: params[:user_name]).exists?
		user = User.new(
			name: params[:name],
			user_name: params[:user_name],
			mail: params[:mail],
			color: params[:color],
			password: params[:password],
			password_confirmation: params[:password_confirmation]
		)
		if user.save
			number = Base64.decode64(params[:secret_mail_id]) # 暗号の暗号を解読
			token =  Token.find_by_token(number)
			if token && token.expired_at > Time.now # 暗号がDBにあれば時間外か確認
				token.update(expired_at: Time.now) # DBが時間内であれば時間外にして
				session[:user] = user.id unless user.nil?
				alert
				redirect '/room'
			else # DBが時間外なら↓を実行
				@message = "入力されたメールアドレスは本登録が完了していいるかURLの有効期限が切れています"
				erb :message, layout: :layout
			end
		else
			@message = '不明なエラーが発生しました'
			alert
			erb :message, layout: :layout
		end
	else
		@message = 'すでに使われているUserNameです'
		alert
		erb :message, layout: :layout
	end
end

get '/account' do
	@message = '仮登録が完了しました。先ほど入力いただいたメールアドレスに、確認メールのメールを送信いたしましたので、そちらの方から、本登録をお願いいたします'
  erb :message, layout: :layout
end
