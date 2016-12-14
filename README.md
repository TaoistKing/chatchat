# Chatchat
A simple chat system demostrating how to build chat applications based on WebRTC, socket.io &amp; Node.js

This system including a web server, a web client, and an iOS client, supports realtime text/voice/video chat.

The iOS client supports [voip socket](https://developer.apple.com/library/ios/technotes/tn2277/_index.html#//apple_ref/doc/uid/DTS40010841-CH1-SUBSECTION15) mode which means it could receive message even in background
>Note: Since voip mode is deprecated from iOS 10, so you can no longer receive messages from background anymore. Refer [here](https://forums.developer.apple.com/thread/50106).

#About WebRTC
WebRTC is an open framework for the web that enables Real Time Communications in the browser. It includes the fundamental building blocks for high-quality communications on the web, such as network, audio and video components used in voice and video chat applications.

Home page          : https://webrtc.org/

Source             : https://chromium.googlesource.com/external/webrtc

#About Socket.io
Socket.IO is a JavaScript library for realtime web applications. It enables realtime, bi-directional communication between web clients and servers. It has two parts: a client-side library that runs in the browser, and a server-side library for node.js. Both components have a nearly identical API. Like node.js, it is event-driven.

Socket.IO primarily uses the WebSocket protocol with polling as a fallback option, while providing the same interface. Although it can be used as simply a wrapper for WebSocket, it provides many more features, including broadcasting to multiple sockets, storing data associated with each client, and asynchronous I/O.

Home page              : http://socket.io/

Socket.io webserver    : https://github.com/socketio/socket.io

Socket.io swift client : https://github.com/socketio/socket.io-client-swift


#Deploy steps
##run your server
Make sure [Node](https://nodejs.org/en/) is installed first, then open your terminal
```
cd Server

npm install

node index.js
```
##run your web client
- open [localhost:3000](http://localhost:3000) on your browser 
- type in your nickname and submit

##run your iOS client
- install dependency with `pod install`
- open xcworkspace file
- build and run
- upon application launch, type in your host address(server address you are running on)
- choose anyone online and start video chat

Enjoy chating! :smile:
