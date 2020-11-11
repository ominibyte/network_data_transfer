part of 'host.dart';

/// A device has an IP address and can listen on a port for connections if it functions as an AP.
/// The design does not currently allow multiple connections using different ports from the same device.
class Device{
  final String _ip; // The device IP address
  final int _port;  // The listening port
  String _name;  // The user can tag this device
  Socket _socket;  // The connection socket for this device
  bool _isConnected;  // If this device has reliable socket connection with the server

  static const _UNKNOWN_DEVICE = "Unknown Device";

  Device(String ip, int port) : _ip = ip, _port = port{
    assert(ip != null);
    assert(port != null);
  }

  Device.from({String ip, int port, String name = _UNKNOWN_DEVICE}) :
        _ip = ip, _port = port, _name = name{
    assert(ip != null);
    assert(port != null);
  }

  /// Get the IP address registered for this host
  String get ip => _ip;
  /// Get the communication port registered for this host
  int get port => _port;
  /// Get the name reported for this Device. This value may be the text "null"
  /// if the Host name was not set in the Server or Client.
  String get name => _name;
  /// Set a name for this Device.
  set name(String name) => _name = name ?? _UNKNOWN_DEVICE;

  // Internal method used to set the connection state of this Device
  set _connected(Socket socket){
    _socket = socket;
    _isConnected = _socket != null;
  }

  /// Used to determine if messages can be sent to this host
  bool get connected => _socket != null && _isConnected;

  // For now devices are unique based on their IP addresses irrespective of ports
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Device && runtimeType == other.runtimeType && _ip == other._ip;

  @override
  int get hashCode => _ip.hashCode;

  @override
  String toString() {
    return 'Device{ip: $_ip, port: $_port, name: $_name}';
  }
}