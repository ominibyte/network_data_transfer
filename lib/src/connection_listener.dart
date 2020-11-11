part of 'host.dart';

/// Classes that implements this can listen and get notified when
/// there's a connection/disconnection on any device as well as message received.
///
/// The Server does not guarantee that onConnected will only be fired once for every device.
/// It can be fired multiple times based on connection and disconnection.
abstract class ConnectionListener{
  /// When a new socket connection is received, this method will be called.
  /// This method can be called multiple times for a discovered device if the
  /// device disconnects and reconnects. [device] contains information on the Device.
  void onConnected(Device device);

  /// When the socket connection closes either normally or due to an error,
  /// this method is called. If the connection closed without error, [isError]
  /// will be false. If an error occurred, you can retrieve the error using
  /// [error]. [stackTrace] may be null is the error provider does not send one.
  /// [device] contains the object to the Device that was disconnected.
  void onDisconnected(Device device, bool isError, Object error, StackTrace stackTrace);

  /// When a message is received from a [device], this method is called with
  /// the received message as a [Packet]
  void onMessage(Packet packet, Device device);
}