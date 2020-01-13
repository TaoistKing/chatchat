var express = require('express');
var app = express();
var http = require('http').Server(app);
var users = {};
var fs = require('fs');
var privateKey = fs.readFileSync('public/key/private.pem','utf8');
var certificate = fs.readFileSync('public/key/file.crt', 'utf8');
var credentials = {key: privateKey, cert: certificate};
var https = require('https').Server(credentials, app);
var io = require('socket.io')(https);

app.use(express.static(__dirname + '/public'));

function findUserByUID(uid){
  return users[uid];
}

function censor(key, value) {
  if (key == 'socketid') {
    return undefined;
  }
  return value;
}

app.get('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
});

app.get('/webrtc', function(req, res){
  console.log(__dirname);
  res.sendFile(__dirname + '/webrtc.html');
});

app.get('/listUsers', function(req, res){
  res.end(JSON.stringify(users, censor));
});


io.on('connection', function(socket){
  console.log('a user connected');
  
  socket.on('disconnect', function(){
    console.log('user disconnected');
    if(socket.uuid){
    	var usr = findUserByUID(socket.uuid);
    	delete users[socket.uuid];
    	socket.broadcast.emit('user leave', {id: usr.id, name:usr.name});
    }
  });
  
  socket.on('chat message', function(msg){
    if(msg.to == 'all'){
      socket.broadcast.emit('chat message', msg);
    }else{
      var target = findUserByUID(msg.to);
      if(target){
        socket.broadcast.to(target.socketid).emit('chat message', msg);
        //socket_to.emit("chat message", msg);
      }else{
        socket.broadcast.emit("chat message", msg);
      }
    }
  });
  
  socket.on('register', function(info){
	console.log("register request: " + info.name);
	if(findUserByUID(info.name) == null){
		var usr = {id: info.name, name: info.name, socketid: socket.id};
		users[info.name] = usr;
		socket.emit('register succeed', {id: info.name, name: info.name});
		socket.broadcast.emit('new user', {id: info.name, name: info.name});
		socket.uuid = info.name;
	}else{
		socket.emit('register failed', {info: "name exist"});
	}
  
  });
  
});

var server = http.listen(3000, function(){
  var host = server.address().address
  var port = server.address().port
  console.log('listening on http://%s:%s', host, port);
});

https.listen(3001, function(){
  console.log('listening on https://:3001');
});

