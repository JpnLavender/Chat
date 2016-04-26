window.onload = function(){
  (function(){
    var show = function(el){
      return function(msg){ el.innerHTML = msg + '<br />' + el.innerHTML; }
    }(document.getElementById('msgs'));

    var $msg = $('#msgs');
    var appendMessage = function (username, color, body) {
      $msg.prepend("<tr><td><font color='" + color + "'>" + username + "→" +"</font>" + body + "</td></tr>")
    };

    var ws       = new WebSocket('ws://' + window.location.host + window.location.pathname);
    // ws.onopen    = function()  { show('JoinRoom'); };
    ws.onclose   = function()  { show('websocket closed'); }
    ws.onmessage = function(m) { 
      if (m.type === "message") {  
        data = JSON.parse(m.data);
        appendMessage(data.user.name, data.user.color, data.body)
        console.log(data.user.name + "send messge")
      }
      else if (m.type === "typing now") {
        console.log("ws send typing")
            }
      else if(m.type === "stop typing"){
        console.log("ws send stop typing")
        //xさんがタイピングをやめたら表示を消す
      }
    };

    //まず、Aさんが文字入力を始めてServerに文字を打っていることを送信する
    //そしてServerから参加者全員に、Aさんが文字入力をしていと、伝える
    //伝えられたデータをもとにJqueryでChat欄にAさんが文字入力中と表示する。

    // ws.onopen = function (socket) {
    //   // when the client emits 'typing', we broadcast it to others
    //   socket.on('typing', function () {
    //     socket.broadcast.emit('typing', {
    //       username: data.user.name
    //     });
    //   });
    //   // when the client emits 'stop typing', we broadcast it to others
    //   socket.on('stop typing', function () {
    //     socket.broadcast.emit('stop typing', {
    //       username: data.user.name
    //     });
    //   });
    //   // echo globally (all clients) that a person has connected
    //   socket.broadcast.emit('user joined', {
    //     username: data.user.name,
    //     numUsers: numUsers
    //   });
    // };

    var sender = function(f){
      var input     = document.getElementById('input');
      input.onclick = function(){ input.value = "" };
      f.onsubmit    = function(){
        ws.send(input.value);
        input.value = "";
        return false;
      }
    }(document.getElementById('form'));
  })();
}

