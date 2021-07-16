import 'dart:convert';
// import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_test_webrtc/socketUtils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Web RTC'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  bool _canAnswer = false;

  bool _ismuted = false;
  bool _isCameraOn = true;

  String roomId;

  RTCPeerConnection _peerConnection;
  MediaStream _localStream;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  _callReceived(String room) {
    roomId = room;

    if (this.mounted) {
      setState(() {
        _canAnswer = true;
      });
    }
  }

  _answerCall() {
    SocketUtils.answerCall(roomId);
  }

  _mute() {
    if (this.mounted) {
      setState(() {
        _ismuted = !_ismuted;

        if (_localStream != null) {
          Helper.setMicrophoneMute(
              _ismuted, _localStream.getAudioTracks()[0]);
        }
      });
    }
  }

  _changeCamera() async {
    if (_localStream != null) {
      await Helper.switchCamera(_localStream.getVideoTracks()[0]);
    }
  }

  _shutCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
      _localStream.getVideoTracks()[0].enabled = _isCameraOn;
    });
  }

  @override
  void initState() {
    SocketUtils.init();
    SocketUtils.callReceivedListener(_callReceived);
    SocketUtils.callAnsweredListener(_createOffer);
    SocketUtils.sdpListener(_setRemoteDescription);
    SocketUtils.iceCandidatesListener(_setCandidate);

    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        "facingMode": 'user'
      }
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;

    return stream;
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        { 'url': "stun:stun.l.google.com:19302" }
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": []
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        String ice = json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        });

        SocketUtils.sendCandidate(ice);
      }
    };

    pc.onIceConnectionState = (e) {
      print("ahmed: " + e.toString());
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    pc.onSignalingState = (state) {
      print("ahmed State: " + state.toString());

      if (state == RTCSignalingState.RTCSignalingStateHaveRemoteOffer)
        _createAnswer();
    };

    return pc;
  }

  void _createOffer(String uid) async {
    RTCSessionDescription description = await _peerConnection.createOffer({
      'offerToReceiveVideo': 1
    });

    _offer = true;
    _peerConnection.setLocalDescription(description);

    var session = parse(description.sdp);
    SocketUtils.sendSDP(json.encode(session));
  }

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer({
      'offerToReceiveVideo': 1
    });

    _peerConnection.setLocalDescription(description);

    var session = parse(description.sdp);
    SocketUtils.sendSDP(json.encode(session));
  }

  void _setRemoteDescription(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);
    RTCSessionDescription description = new RTCSessionDescription(sdp, _offer? 'answer' : 'offer');

    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _setCandidate(String jsonString) async {
    dynamic session = await jsonDecode("$jsonString");
    dynamic candidate = new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
    height: 210,
    child: Row(
      children: [
        Flexible(
            child: Container(
              key: Key("local"),
              margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: RTCVideoView(_localRenderer),
            )
        ),
        Flexible(
            child: Container(
              key: Key("remote"),
              margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer),
            )
        )
      ],
    ),
  );

  Row offerAndAnswerButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      RaisedButton(
        onPressed: SocketUtils.startCall,
        child: Text('Call'),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _canAnswer? _answerCall : null,
        child: Text('Answer'),
        color: Colors.amber,
      )
    ],
  );

  Row handleButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      RaisedButton(
        onPressed: _mute,
        child: Text(_ismuted ? 'unmute' : "mute"),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _changeCamera,
        child: Text('Change Camera'),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _shutCamera,
        child: Text((_isCameraOn ? 'Shut' : 'Open') + ' Camera'),
        color: Colors.amber,
      )
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
            handleButtons(),
          ],
        )
      )
    );
  }
}
