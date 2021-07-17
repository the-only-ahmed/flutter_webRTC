import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:flutter_test_webrtc/socketUtils.dart';

class WebRTCUtils {
  bool _offer = false;

  RTCPeerConnection _peerConnection;
  MediaStream _localStream;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();

  init() {
    _initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
  }

  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  RTCVideoRenderer getLocalRenderer() {
    return _localRenderer;
  }

  RTCVideoRenderer getRemoteRenderer() {
    return _remoteRenderer;
  }

  mute(bool micEnabled) {
    if (_localStream != null) {
      _localStream.getAudioTracks()[0].enabled = micEnabled;
    }
  }

  changeCamera() async {
    if (_localStream != null) {
      await Helper.switchCamera(_localStream.getVideoTracks()[0]);
    }
  }

  shutCamera(bool isCameraOn) {
    _localStream.getVideoTracks()[0].enabled = isCameraOn;
  }

  void createOffer(String uid) async {
    RTCSessionDescription description = await _peerConnection.createOffer({
      'offerToReceiveVideo': 1
    });

    _offer = true;
    _peerConnection.setLocalDescription(description);

    var session = parse(description.sdp);
    SocketUtils.sendSDP(json.encode(session));
  }

  void setRemoteDescription(String jsonString) async {
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);
    RTCSessionDescription description = new RTCSessionDescription(sdp, _offer? 'answer' : 'offer');

    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void setCandidate(String jsonString) async {
    dynamic session = await jsonDecode("$jsonString");
    dynamic candidate = new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);

    await _peerConnection.addCandidate(candidate);
  }

  _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        "facingMode": 'user',
        "width": 1024,
        "height": 768
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

  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer({
      'offerToReceiveVideo': 1
    });

    _peerConnection.setLocalDescription(description);

    var session = parse(description.sdp);
    SocketUtils.sendSDP(json.encode(session));
  }
}