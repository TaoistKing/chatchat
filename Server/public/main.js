
var myusername;
var peerusername;
var socket = io();
var pc;
var localStream;
var remoteCandidates = [];
var sendChannel;
var receiveChannel;

$(document).ready(function(){
	console.log("document ready.");
	console.log(adapter.browserDetails.browser);

	$(this).attr('disabled', true).unbind('click');
	// Make sure the browser supports WebRTC
	if(!isWebrtcSupported()) {
		bootbox.alert("No WebRTC support... ");
		return;
	}

	$('#videocall').removeClass('hide').show();
	$('#login').removeClass('hide').show();
	$('#registernow').removeClass('hide').show();
	$('#register').click(registerUsername);
	$('#username').focus();
});


socket.on('register succeed', function(msg){
	myusername = msg["name"];
	console.log("Successfully registered as " + myusername + "!");
	$('#youok').removeClass('hide').show().html("Registered as '" + myusername + "'");
	// Get a list of available peers, just for fun
	//videocall.send({"message": { "request": "list" }});
	// TODO Enable buttons to call now
	$('#phone').removeClass('hide').show();
	$('#call').unbind('click').click(doCall);
	$('#peer').focus();

	openDevices();
});

socket.on('register failed', function(msg){
	console.log("register failed: " + msg.info);
})

socket.on('new user', function(data){
	console.log("new user " + data.name);	
});

socket.on('user leave', function(data){
	console.log(data.name + " left");	
});

socket.on('chat message', function(data){
	//dispatch signal messages to corresponding functions, ie , 
	//onRemoteOffer/ onRemoteAnswer/onRemoteIceCandidate
	//IS this message to me ?
	if(data.to != myusername){
		return;
	}
	//
	if(data.type == 'signal'){
		onSignalMessage(data);
	}else if(data.type == 'text'){
		console.log('received text message from ' + data.from + ', content: ' + data.content);
	}else{
		console.log('received unknown message type ' + data.type + ' from ' + data.from);
	}
});

socket.on('connect', function(){
	console.log("server connected");
});

function isWebrtcSupported() {
	return window.RTCPeerConnection !== undefined && window.RTCPeerConnection !== null;
};

function checkEnter(field, event) {
	var theCode = event.keyCode ? event.keyCode : event.which ? event.which : event.charCode;
        if(theCode == 13) {
                if(field.id == 'username')
                        registerUsername();
                else if(field.id == 'peer')
                     doCall();
		else if(field.id == 'datasend')
			sendData();
			return false;
		} else {
			return true;
		}
}

function sendData() {
  const data = $('#datasend').val();
  sendChannel.send(data);
  console.log('Sent Data: ' + data);
  $('#datasend').val('');
}

function registerUsername() {
	// Try a registration
	$('#username').attr('disabled', true);
	$('#register').attr('disabled', true).unbind('click');
	var username = $('#username').val();
	if(username === "") {
		bootbox.alert("Insert a username to register (e.g., pippo)");
		$('#username').removeAttr('disabled');
		$('#register').removeAttr('disabled').click(registerUsername);
		return;
	}
	if(/[^a-zA-Z0-9]/.test(username)) {
		bootbox.alert('Input is not alphanumeric');
		$('#username').removeAttr('disabled').val("");
		$('#register').removeAttr('disabled').click(registerUsername);
		return;
	}
	var info = { "name": username };
	socket.emit("register", info);
	console.log("trying to register as " + username);
}

function openDevices(){
	var options = {audio:false, video:true};
	navigator.mediaDevices
	      .getUserMedia(options)
	      .then(onLocalStream)
	      .catch(function(e) {
		alert('getUserMedia() failed');
		console.log('getUserMedia() error: ', e);
	      });
}

function onLocalStream(stream) {
	console.log('Received local stream');
	$('#videos').removeClass('hide').show();
	if($('#myvideo').length === 0)
		$('#videoleft').append('<video class="rounded centered" id="myvideo" width=320 height=240 autoplay playsinline muted="muted"/>');
	$('#myvideo').get(0).srcObject = stream;
	$("#myvideo").get(0).muted = "muted";

	var videoTracks = stream.getVideoTracks();
	var audioTracks = stream.getAudioTracks();
	if (videoTracks.length > 0) {
		console.log('Using video device: ' + videoTracks[0].label);
	}
	if (audioTracks.length > 0) {
		console.log('Using audio device: ' + audioTracks[0].label);
	}
	localStream = stream;
}

function createPc(){
	var configuration = { "iceServers": [{ "urls": "stun:stun.ideasip.com" }] };
	pc = new RTCPeerConnection(configuration);
	console.log('Created local peer connection object pc');
	
	sendChannel = pc.createDataChannel("sendchannel");
	sendChannel.onopen = onSendChannelStateChange;
  	sendChannel.onclose = onSendChannelStateChange;

	pc.onicecandidate = function(e) {
		onIceCandidate(pc, e);
	};

	pc.oniceconnectionstatechange = function(e) {
		onIceStateChange(pc, e);
	};

	pc.ondatachannel = receiveChannelCallback;
	pc.ontrack  = gotRemoteTrack;
	pc.addStream(localStream);
	console.log('Added local stream to pc');
}

function doCall() {
	// Call someone
	$('#peer').attr('disabled', true);
	$('#call').attr('disabled', true).unbind('click');
	var username = $('#peer').val();
	if(username === "") {
		bootbox.alert("Insert a username to call (e.g., pluto)");
		$('#peer').removeAttr('disabled');
		$('#call').removeAttr('disabled').click(doCall);
		return;
	}
	if(/[^a-zA-Z0-9]/.test(username)) {
		bootbox.alert('Input is not alphanumeric');
		$('#peer').removeAttr('disabled').val("");
		$('#call').removeAttr('disabled').click(doCall);
		return;
	}
	// Call this user
	peerusername = username;
	
	createPc();

	console.log(' createOffer start');
	var offerOptions = {
	  offerToReceiveAudio: 0,
	  offerToReceiveVideo: 1,
	  voiceActivityDetection: false
	};

	pc.createOffer(
		offerOptions
	).then(
		onCreateOfferSuccess,
		onCreateSessionDescriptionError
	);
}

function onCreateSessionDescriptionError(error) {
	console.log('Failed to create session description: ' + error.toString());
	bootbox.alert("WebRTC error... " + JSON.stringify(error));
}

function onCreateOfferSuccess(desc) {
	  console.log('Offer from pc\n' + desc.sdp);
	  console.log('pc setLocalDescription start');
	  pc.setLocalDescription(desc).then(
		  function() {
		      onSetLocalSuccess(pc);
		  },
		  onSetSessionDescriptionError
	  );

	//Send offer to remote side
	var message = {from: myusername, to:peerusername, type: 'signal', subtype: 'offer', content: desc, time:new Date()};
	socket.emit('chat message', message);
	
	bootbox.alert("Waiting for the peer to answer...");
}

function onSetLocalSuccess(pc) {
	console.log(' setLocalDescription complete');
}

function onSetRemoteSuccess(pc) {
	console.log(' setRemoteDescription complete');
	applyRemoteCandidates();
}

function onSetSessionDescriptionError(error) {
	console.log('Failed to set session description: ' + error.toString());
}

function gotRemoteTrack(e) {
	if($('#remotevideo').length === 0) {
		addButtons = true;
		$('#videoright').append('<video class="rounded centered hide" id="remotevideo" width=320 height=240 autoplay playsinline/>');
		// Show the video, hide the spinner and show the resolution when we get a playing event
		$("#remotevideo").bind("playing", function () {
			if(this.videoWidth)
				$('#remotevideo').removeClass('hide').show();
		});
		$('#callee').removeClass('hide').html(peerusername).show();
	}
	$('#remotevideo').get(0).srcObject = e.streams[0];
	console.log('pc received remote track');
}

function onSignalMessage(m){
	if(m.subtype == 'offer'){
		console.log('got remote offer from ' + m.from + ', content ' + m.content);
		onSignalOffer(m);
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


function onSignalOffer(msg){

	console.log("Incoming call from " + msg["from"] + "!");
	peerusername = msg["from"];
	// Notify user
	bootbox.hideAll();
	incoming = bootbox.dialog({
		message: "Incoming call from " + peerusername + "!",
		title: "Incoming call",
		closeButton: false,
		buttons: {
			success: {
				label: "Answer",
				className: "btn-success",
				callback: function() {
					createPc();
					var Offer = msg["content"];
					incoming = null;
					$('#peer').val(peerusername).attr('disabled', true);
					console.log('on remoteOffer :'+ Offer.sdp);
					pc.setRemoteDescription(Offer).then(function(){
						onSetRemoteSuccess(pc)}, onSetSessionDescriptionError
					);
					pc.createAnswer().then(
						onCreateAnswerSuccess,
						onCreateSessionDescriptionError
					);
				}
			},
			danger: {
				label: "Decline",
				className: "btn-danger",
				callback: function() {
					doHangup();
				}
			}
		}
	});
}

function onSignalCandidate(candidate){
	onRemoteIceCandidate(candidate);
}

function onSignalAnswer(answer){
	bootbox.hideAll();
	onRemoteAnswer(answer);
}
	
function onSignalClose(){
	bootbox.hideAll();
  	console.log('Call end ');
	pc.close();
	pc = null;
	
	peerusername = null;
	clearViews();
}

function onRemoteAnswer(answer){
	console.log('onRemoteAnswer : ' + answer);
	pc.setRemoteDescription(answer).then(function(){onSetRemoteSuccess(pc)}, onSetSessionDescriptionError);
	$('#call').removeAttr('disabled').html('Hangup')
		.removeClass("btn-success").addClass("btn-danger")
		.unbind('click').click(doHangup);
}


function onRemoteIceCandidate(candidate){
	console.log('onRemoteIceCandidate : ' + candidate);
	if(pc){
		addRemoteCandidate(candidate);
	}else{
		remoteCandidates.push(candidate);
	}
}

function applyRemoteCandidates(){
	for(var candidate in remoteCandidates){
		addRemoteCandidate(candidate);
	}
	remoteCandidates = [];
}

function addRemoteCandidate(candidate){
	pc.addIceCandidate(candidate).then(
      function() {
        onAddIceCandidateSuccess(pc);
      },
      function(err) {
        onAddIceCandidateError(pc, err);
      });
}


function onCreateAnswerSuccess(desc) {
	console.log('onCreateAnswerSuccess');

	pc.setLocalDescription(desc).then(
		function() {
			onSetLocalSuccess(pc);
		},
		onSetSessionDescriptionError
	);
  
	$('#peer').attr('disabled', true);
	$('#call').removeAttr('disabled').html('Hangup')
		.removeClass("btn-success").addClass("btn-danger")
		.unbind('click').click(doHangup);

	//Sent answer to remote side
  	var message = {from: myusername, to:peerusername, type: 'signal', subtype: 'answer', content: desc, time:new Date()};
	socket.emit('chat message', message);
}


function onIceCandidate(pc, event) {
  if (event.candidate) {
    	console.log( ' ICE candidate: \n' + event.candidate.candidate);
    
    	//Send candidate to remote side
    	var message = {from: myusername, to:peerusername, type: 'signal', subtype: 'candidate', content: event.candidate, time:new Date()};
	socket.emit('chat message', message);
  }
}

function onAddIceCandidateSuccess(pc) {
	console.log( ' addIceCandidate success');
}

function onAddIceCandidateError(pc, error) {
	console.log( ' failed to add ICE Candidate: ' + error.toString());
}

function onIceStateChange(pc, event) {
  if (pc) {
    console.log( ' ICE state: ' + pc.iceConnectionState);
    console.log('ICE state change event: ', event);
  }
}


function onSendChannelStateChange() {
  const readyState = sendChannel.readyState;
  console.log('Send channel state is: ' + readyState);
  if (readyState === 'open') {
  	$('#datasend').removeAttr('disabled');
  } else {
  	$('#datasend').attr('disabled', true);
  }
}

function receiveChannelCallback(event) {
  console.log('Receive Channel Callback');
  receiveChannel = event.channel;
  receiveChannel.onmessage = onReceiveMessageCallback;
  receiveChannel.onopen = onReceiveChannelStateChange;
  receiveChannel.onclose = onReceiveChannelStateChange;
}

function onReceiveMessageCallback(event) {
  console.log('Received Message');
  $('#datarecv').val(event.data);
}

function onReceiveChannelStateChange() {
  const readyState = receiveChannel.readyState;
  console.log(`Receive channel state is: ${readyState}`);
}

	
function doHangup() {
	console.log('Hangup call');
	sendChannel.close();
	receiveChannel.close();

	pc.close();
	pc = null;
  
  
  	//Send signal to remote side
    	var message = {from: myusername, to:peerusername, type: 'signal', subtype: 'close', content: 'close', time:new Date()};
	socket.emit('chat message', message);

	peerusername = null;
	clearViews();
}


function clearViews(){
	//$('#myvideo').remove();
	$('#remotevideo').remove();
	$("#videoleft").parent().unblock();
	$('#callee').empty().hide();
	peerusername = null;
	//$('#videos').hide();

	$('#call').removeAttr('disabled').unbind('click').click(doCall).html('Call').removeClass("btn-danger").addClass("btn-success");
	$('#peer').removeAttr('disabled').val("");

	$('#datasend').val('');
	$('#datarecv').val('');
	$('#datasend').attr('disabled', true);
	$('#datarecv').attr('disabled', true);
}

