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

  String get ip => _ip;
  int get port => _port;
  String get name => _name;
  set name(String name) => _name = name ?? _UNKNOWN_DEVICE;

  // For now devices are unique based on their IP addresses irrespective of ports
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && _ip == other._ip;

  @override
  int get hashCode => _ip.hashCode;

  set _connected(Socket socket){
    _socket = socket;
    _isConnected = _socket != null;
  }

  bool get connected => _socket != null && _isConnected;
}