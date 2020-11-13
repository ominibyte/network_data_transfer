part of 'host.dart';

/// This interface allows you to listen to events from multicast group used for
/// service discovery and advertisement.
///
/// Events received using this interface gives you a Device handle which you cannot
/// use directly with [Client.send] or [Server.send] because they do not contain
/// a communication socket. On the Client, you should use [Client.connectTo] to
/// create a reliable socket connection to the Server Device when an event is received
/// using [onDiscovery]. The [Device.port] is changed in [onDiscovery] to the port
/// which the server is listening on for reliable socket connections.
///
/// It may not be possible to use [Client.connectTo] with the [Device] received
/// using [onAdvertisement] because that is a custom message that does not include
/// the port which the Server is listening on. The [Device.port] from the Device
/// received in [onAdvertisement] is the one the Server is advertising from which
/// will mostly be different from the one they are listening on for reliable connection.
/// Your messages will need to include the port from the Server or you can use a static
/// port and create a new Device together with the IP address which you will pass to
/// [Client.connectTo]. e.g client.connectTo(new Device(device.ip, myPortNumber))
abstract class DeviceDiscoveryListener{
  /// This method is called when a new device is discovered using the internal
  /// discovery mechanism. The message sent here is a PING - PONG request reply.
  /// The latest discovered device is provided as [newDevice]. For convenience,
  /// all discovered devices using the internal discovery mechanism are sent to
  /// this method as [allDevices]. This method would not be recalled
  /// if a device disconnect and reconnects. For active connection and disconnections
  /// events, use [ConnectionListener.onConnected] and [ConnectionListener.onDisconnected]
  /// respectively.
  void onDiscovery(Device newDevice, Iterable<Device> allDevices);

  /// This method is called when the Server sends a custom advertisement message.
  /// or an unreliable broadcast message using Server.broadcast()
  ///
  /// The message received from the [device] is contained in [packet]
  ///
  /// Please note that you may not be able to send a message directly to the Device
  /// received here. Messages can mostly only be sent to Devices received after
  /// an event is received from [ConnectionListener.onConnected] which is triggered
  /// when a Client uses [Client.connectTo] to initiate a connection
  void onAdvertisement(Device device, Packet packet);

  /// When the multicast connection closes either normally or due to an error,
  /// this method is called. If the connection closed without error, [isError]
  /// will be false. If an error occurred, you can retrieve the error using
  /// [error]. [stackTrace] may be null is the error provider does not send one.
  void onClose(bool isError, Object error, StackTrace stackTrace);
}