# chatchat
A simple chat system demostrating how to build chat applications based on socket.io &amp; Node.js

This system including a web server, a web client, and an iOS client

The iOS client supports [voip socket](https://developer.apple.com/library/ios/technotes/tn2277/_index.html#//apple_ref/doc/uid/DTS40010841-CH1-SUBSECTION15) mode which means it could receive message even in background
#components
Socket.io webserver    : https://github.com/socketio/socket.io

Socket.io swift client : https://github.com/socketio/socket.io-client-swift

##run your server
Make sure Node is installed first, then open your terminal
```
cd Server

npm install

node index.js
```
##run your web client
Open [localhost:3000](http://localhost:3000) on your browser 

>Note: all messages sent from Web will be broadcast message

##run your iOS client
- install dependency with `pod install`
- open xcworkspace file
- build and run
- upon application launch, type in your host address(server address you are running on)

>Note: all messages sent from iOS will be singlecast message


Enjoy chating! :smile:
