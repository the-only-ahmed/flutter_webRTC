import 'package:flutter/material.dart';

import 'package:flutter_test_webrtc/webrtcUtils.dart';
import 'package:flutter_test_webrtc/socketUtils.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

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
  WebRTCUtils _webRTCUtils = new WebRTCUtils();
  bool _canAnswer = false;

  bool _micEnabled = true;
  bool _isCameraOn = true;

  String roomId;

  @override
  void dispose() {
    // _webRTCUtils.dispose();
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
        _micEnabled = !_micEnabled;
        _webRTCUtils.mute(_micEnabled);
      });
    }

  }

  _shutCamera() {
    setState(() {
      _isCameraOn = !_isCameraOn;
      _webRTCUtils.shutCamera(_isCameraOn);
    });
  }

  @override
  void initState() {
    SocketUtils.init();
    SocketUtils.callReceivedListener(_callReceived);
    SocketUtils.callAnsweredListener(_webRTCUtils.createOffer);
    SocketUtils.sdpListener(_webRTCUtils.setRemoteDescription);
    SocketUtils.iceCandidatesListener(_webRTCUtils.setCandidate);

    _webRTCUtils.init();
    super.initState();
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
              child: new RTCVideoView(_webRTCUtils.getLocalRenderer()),
            )
        ),
        Flexible(
            child: Container(
              key: Key("remote"),
              margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_webRTCUtils.getRemoteRenderer()),
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
        child: Text(_micEnabled ? 'mute' : "unmute"),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _webRTCUtils.changeCamera,
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
