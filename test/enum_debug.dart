import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  test('debug enums', () {
    print('DC_STATES_START');
    for (var v in RTCDataChannelState.values) {
      print(v);
    }
    print('DC_STATES_END');

    print('PC_STATES_START');
    for (var v in RTCPeerConnectionState.values) {
      print(v);
    }
    print('PC_STATES_END');
  });
}
