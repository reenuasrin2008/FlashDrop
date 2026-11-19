import 'package:flashdrop/transport/nearby_transport.dart';
import 'package:flashdrop/transport/peer_transport.dart';

class TransportFactory {
  TransportFactory._();

  static PeerTransport createDefault() => NearbyTransport();
}
