
'use strict';

function trace(arg) {
  var now = (window.performance.now() / 1000).toFixed(3);
  console.log(now + ': ', arg);
}

var startTime;
var localVideo = document.getElementById('localVideo');
var remoteVideo = document.getElementById('remoteVideo');

localVideo.addEventListener('loadedmetadata', function() {
  trace('Local video videoWidth: ' + this.videoWidth +
    'px,  videoHeight: ' + this.videoHeight + 'px');
});

remoteVideo.addEventListener('loadedmetadata', function() {
  trace('Remote video videoWidth: ' + this.videoWidth +
    'px,  videoHeight: ' + this.videoHeight + 'px');
});

remoteVideo.onresize = function() {
  trace('Remote video size changed to ' +
    remoteVideo.videoWidth + 'x' + remoteVideo.videoHeight);
  // We'll use the first onsize callback as an indication that video has started
  // playing out.
  if (startTime) {
    var elapsedTime = window.performance.now() - startTime;
    trace('Setup time: ' + elapsedTime.toFixed(3) + 'ms');
    startTime = null;
  }
};


var localStream;
var pc;
var offerOptions = {
  offerToReceiveAudio: 1,
  offerToReceiveVideo: 1
};
var remoteCandidates = [];
var peerConnectionDidCreate = false;
var candidateDidReceived = false;
var ruid;
var luid;

var answerButton = document.getElementById('answerButton');
var denyButton   = document.getElementById('denyButton');
var startVideoButton = document.getElementById('startVideoButton');
var videoBackButton = document.getElementById('videoBackButton');

startVideoButton.onclick = startVideo;
answerButton.onclick = answerCall;
videoBackButton.onclick = hangup;

function startVideo(){
	isCaller = true;
}

$('#videoPage').on('pagecreate', function(){
	console.log('video page did create');
	//$.getScript("js/main.js");
	//$.getScript("css/main.css");
});

$('#videoPage').on('pageshow', function(){
	console.log('video page did show');
	console.log('local: ' + uuid);
	luid = Cookies.get('uuid');
	console.log('local in cookie: ' + luid);
	ruid = Cookies.get('remoteUUID');
	console.log('remote ' + ruid);
	start();
});
	
function gotStream(stream) {
  trace('Received local stream');
  localVideo.srcObject = stream;
  localStream = stream;
  
  call();
}

function start() {
	console.log('start');
  trace('Requesting local stream');
  navigator.mediaDevices.getUserMedia({
    audio: true,
    video: true
  })
  .then(gotStream)
  .catch(function(e) {
    alert('getUserMedia() error: ' + e.name);
  });
}

function call() {
  trace('Starting call');
  startTime = window.performance.now();
  var videoTracks = localStream.getVideoTracks();
  var audioTracks = localStream.getAudioTracks();
  if (videoTracks.length > 0) {
    trace('Using video device: ' + videoTracks[0].label);
  }
  if (audioTracks.length > 0) {
    trace('Using audio device: ' + audioTracks[0].label);
  }
  var servers = null;
  pc = new RTCPeerConnection(servers);
  trace('Created local peer connection object pc');
  
  pc.onicecandidate = function(e) {
    onIceCandidate(pc, e);
  };

  pc.oniceconnectionstatechange = function(e) {
    onIceStateChange(pc, e);
  };

  pc.onaddstream = gotRemoteStream;

  pc.addStream(localStream);
  trace('Added local stream to pc');
	
	peerConnectionDidCreate = true;
	
	if(isCaller){
		trace(' createOffer start');
		pc.createOffer(
			offerOptions
		).then(
			onCreateOfferSuccess,
			onCreateSessionDescriptionError
		);
	}else{
		onAnswer();
	}
}

function onCreateSessionDescriptionError(error) {
  trace('Failed to create session description: ' + error.toString());
}

function onCreateOfferSuccess(desc) {
  trace('Offer from pc\n' + desc.sdp);
  trace('pc1 setLocalDescription start');
  pc.setLocalDescription(desc).then(
    function() {
      onSetLocalSuccess(pc);
    },
    onSetSessionDescriptionError
  );

	//Send offer to remote side
	var message = {from: luid, to:ruid, type: 'signal', subtype: 'offer', content: desc, time:new Date()};
	socket.emit('chat message', message);
}

function onSetLocalSuccess(pc) {
  trace(' setLocalDescription complete');
}

function onSetRemoteSuccess(pc) {
  trace(' setRemoteDescription complete');
  applyRemoteCandidates();
}

function onSetSessionDescriptionError(error) {
  trace('Failed to set session description: ' + error.toString());
}

function gotRemoteStream(e) {
  remoteVideo.srcObject = e.stream;
  trace('pc received remote stream');
}

function onSignalMessage(m){
	if(m.subtype == 'offer'){
		console.log('got remote offer from ' + m.from + ', content ' + m.content);
		Cookies.set('remoteUUID', m.from);
		onSignalOffer(m.content);
	}else if(m.subtype == 'answer'){
		onSignalAnswer(m.content);
	}else if(m.subtype == 'candidate'){
		onSignalCandidate(m.content);
	}else if(m.subtype == 'close'){
		onSignalClose();
	}else{
		console.log('unknown signal type ' + m.subtype);
	}
}


function onSignalOffer(offer){
	Cookies.set('offer', offer);
	//location.href = '#incomingVideo';
	$.mobile.changePage('#incomingVideo');
}

function onSignalCandidate(candidate){
	var c = candidate;
	if(typeof(candidate) == 'string'){
		c = JSON.parse(candidate);
	}
	var d = JSON.parse(candidate);
	onRemoteIceCandidate(d);
}

function onSignalAnswer(answer){
	onRemoteAnswer(answer);
}
	
function onSignalClose(){
  	trace('Call end ');
	pc.close();
	pc = null;
	
	closeMedia();
	clearView();
	location.href = '#listPage';
}

function onRemoteAnswer(answer){
	trace('onRemoteAnswer : ' + answer);
	pc.setRemoteDescription(answer).then(function(){onSetRemoteSuccess(pc)}, onSetSessionDescriptionError);
}


function onRemoteIceCandidate(candidate){
	trace('onRemoteIceCandidate : ' + candidate);
	if(peerConnectionDidCreate){
		addRemoteCandidate(candidate);
	}else{
		//remoteCandidates.push(candidate);
		var candidates = Cookies.getJSON('candidate');
		if(candidateDidReceived){
			candidates.push(candidate);
		}else{
			candidates = [candidate];
			candidateDidReceived = true;
		}
		Cookies.set('candidate', candidates);
	}
}

function applyRemoteCandidates(){
	var candidates = Cookies.getJSON('candidate');
	for(var candidate in candidates){
		addRemoteCandidate(candidates[candidate]);
	}
	Cookies.remove('candidate');
}

function addRemoteCandidate(candidate){
	pc.addIceCandidate(new RTCIceCandidate(candidate)).then(
      function() {
        onAddIceCandidateSuccess(pc);
      },
      function(err) {
        onAddIceCandidateError(pc, err);
      });
}


function onAnswer(){
	var remoteOffer = Cookies.get('offer');
	var offer = JSON.parse(remoteOffer);

	pc.setRemoteDescription(offer).then(function(){onSetRemoteSuccess(pc)}, onSetSessionDescriptionError);

	pc.createAnswer().then(
		onCreateAnswerSuccess,
    	onCreateSessionDescriptionError
    );
}

function onCreateAnswerSuccess(desc) {
  trace('onCreateAnswerSuccess');
  pc.setLocalDescription(desc).then(
    function() {
      onSetLocalSuccess(pc);
    },
    onSetSessionDescriptionError
  );
  
	//Sent answer to remote side
  	var message = {from: luid, to:ruid, type: 'signal', subtype: 'answer', content: desc, time:new Date()};
	socket.emit('chat message', message);
}


function onIceCandidate(pc, event) {
  if (event.candidate) {
    trace( ' ICE candidate: \n' + event.candidate.candidate);
    
    //Send candidate to remote side
    var message = {from: luid, to:ruid, type: 'signal', subtype: 'candidate', content: event.candidate, time:new Date()};
	socket.emit('chat message', message);
  }
}

function onAddIceCandidateSuccess(pc) {
  trace( ' addIceCandidate success');
}

function onAddIceCandidateError(pc, error) {
  trace( ' failed to add ICE Candidate: ' + error.toString());
}

function onIceStateChange(pc, event) {
  if (pc) {
    trace( ' ICE state: ' + pc.iceConnectionState);
    console.log('ICE state change event: ', event);
  }
}

function answerCall(){
	isCaller = false;
	location.href = '#videoPage';
}
	
function hangup() {
  trace('Hangup call');
  pc.close();
  pc = null;
  
  closeMedia();
  clearView();
  
  //Send candidate to remote side
    var message = {from: luid, to:ruid, type: 'signal', subtype: 'close', content: 'close', time:new Date()};
	socket.emit('chat message', message);
}

function closeMedia(){
	localStream.getTracks().forEach(function(track){track.stop();});
}

function clearView(){
	localVideo.srcObject = null;
	remoteVideo.srcObject = null;
}

