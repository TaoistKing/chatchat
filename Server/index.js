var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);
var users = [];
var sockets = [];
var index = 0;


function findIndexByUID(uid){
  var i;
  for(i = 0; i < users.length; i++){
    if(users[i].id == uid) break;
  }

  if(i == users.length) return -1;
  
  return i;
}

function findUserByUID(uid){
  var index = findIndexByUID(uid);
  if(index == -1) return null;
  
  return users[index];
}

function findSocketByUID(uid){
  var index = findIndexByUID(uid);
  
  if(index == -1)  return null;
  return sockets[index];
}

app.get('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
});

app.get('/listUsers', function(req, res){
  res.end(JSON.stringify(users));
});

io.on('connection', function(socket){
  console.log('a user connected');
  
  socket.on('disconnect', function(){
    console.log('user disconnected');
    var index = sockets.indexOf(socket);
    if(index != -1){
      var usr = users[index];
      users.splice(index, 1);
      sockets.splice(index, 1);
      socket.broadcast.emit('user leave', usr);
    }
  });
  
  socket.on('chat message', function(msg){
    if(msg.to == 'all'){
      io.emit('chat message', msg);
    }else{
      var socket_to = findSocketByUID(JSON.parse(msg).to);
      if(socket_to){
        socket_to.emit("chat message", msg);
      }else{
        socket.broadcast.emit("chat message", msg);
      }
    }
    
  });
  
  socket.on('register', function(info){

    if(sockets.indexOf(socket) == -1){
      var usr = {id: info.uuid, name: info.name};
      users.push(usr);
      sockets.push(socket);
      socket.emit('register succeed', usr);
      socket.broadcast.emit('new user', usr);
      index++;
    }
  
  });
  
});

var server = http.listen(3000, function(){
  var host = server.address().address
  var port = server.address().port
  console.log('listening on http://%s:%s', host, port);
});

