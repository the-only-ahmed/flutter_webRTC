import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:socket_io_client/socket_io_client.dart';

class SocketUtils {
  static const String SOCKET_URL = '*********************************';
  static IO.Socket _socket;

  static init() {
    _socket = IO.io(
        SOCKET_URL,
        OptionBuilder().setTransports(['websocket']) // for Flutter or Dart VM
            // .disableAutoConnect()
            // disable auto-connection
            // optional
            .build());

    _socket.onConnect((_) => print("socket connected"));

    _socket.onReconnect((_) => {
      print("socket reconnectd")
    });
  }

  static void startCall() {
    _socket.emit('startCall');
  }

  static void answerCall(String room) {
    _socket.emit('answer', room);
  }

  static void sendSDP(String sdp) {
    _socket.emit('sdp', sdp);
  }

  static void sendCandidate(String sdp) {
    _socket.emit('ice', sdp);
  }
  
  static void callReceivedListener(Function(String) callStarted) {
    _socket.on("call started", (room) => callStarted(room));
  }

  static void callAnsweredListener(Function(String) callAnswered) {
    _socket.on("call answered", (data) => callAnswered(data));
  }

  static void sdpListener(Function(String) sdpReceived) {
    _socket.on('sdp', (sdp) => sdpReceived(sdp));
  }

  static void iceCandidatesListener(Function(String) iceCandidateReceived) {
    _socket.on('ice candidates', (ice) => iceCandidateReceived(ice));
  }

  static void disconnect() {
    _socket.disconnect();
  }  
}