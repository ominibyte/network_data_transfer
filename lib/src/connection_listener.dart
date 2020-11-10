part of 'host.dart';

/// Classes that implements this can listen and get notified when
/// there's a connection/disconnection on any device as well as message received.
/// The Server does not guarantee that onConnected will not be fired once.
/// It can be fired multiple times based on connection and disconnection.

abstract class ConnectionListener{
  void onConnected(Device device);
  void onDisconnected(Device device);
  void onMessage(Packet packet);
}