# chatchat
A simple chat system demostrating how to build chat applications based on socket.io &amp; Node.js

this system including a web server, a web client, and an iOS client

the iOS client supports [voip socket](https://developer.apple.com/library/ios/technotes/tn2277/_index.html#//apple_ref/doc/uid/DTS40010841-CH1-SUBSECTION15) mode which means it could receive message even in background
#components
Socket.io webserver    : https://github.com/socketio/socket.io

Socket.io swift client : https://github.com/socketio/socket.io-client-swift

##run your server
make sure Node is installed first, then open your terminal
```
cd Server

npm install

node index.js
```
##run your web client
open [localhost:3000](http://localhost:3000) on your browser 

Note: all messages sent from Web will be a broadcast message

##run your iOS client
Build and run Chatchat on your iOS devices.
Upon application launch, type in your host address(server address you are running on)

Note: all messages sent from iOS will be a singlecast message


enjoy chating!
