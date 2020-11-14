/// This library allows Client-Server communication with service discovery
/// and abstracts communication primitives and communication data using [Packet]s.
///
/// You can receive multicast/broadcast discovery/advertisement events with
/// [DeviceDiscoveryListener] as well as receive reliable communication events
/// using [ConnectionListener]. Create Servers using the [Server] class and clients
/// using the [Client] class.
library network_data_transfer;

import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

part 'client.dart';
part 'server.dart';
part 'device.dart';
part 'device_discover_listener.dart';
part 'connection_listener.dart';
part 'packet.dart';

/// A Host is a generic endpoint (STA/AP) in the network.
/// A Client and a Server are both hosts.
abstract class Host{
  // The default discovery port to listen on if the user does not specify any
  static const int DEFAULT_MULTICAST_PORT = 5018;
  // The multicast group the devices should join
  static const String DEFAULT_MULTICAST_GROUP_IPV4 = "225.225.225.225";
  static const String DEFAULT_MULTICAST_GROUP_IPV6 = "FF02::FB";
  // The actual multicast discovery port to listen on.
  int _multicastPort;
  IPVersion _ipVersion;
  RawDatagramSocket _multicastSocket;
  Completer<bool> _readyCompleter = Completer();
  String _ipAddress;  // The IP address for this host which we will be using
  Set<Device> _discoveredDevices; // Devices that we find during the discovery/handshake
  Timer _timer;
  String _multicastGroupIP;
  DeviceDiscoveryListener _discoveryListener;
  ConnectionListener _connectionListener;
  String _name; // A name/identifier to give this host

  /**
   * [name] is useful for host/device identification purposes especially if discovery
   * is enabled. If you specify a name, the name will be sent to communicating devices
   * to add as a user friendly name during discovery.
   *
   * You can specify a [multicastPort] if you want to use something else instead
   * of the default 5018. This is the port that the multicast group will be listening on.
   * You only need to set this if you plan to enable device discovery and advertisements.
   *
   * [ipVersion] is the version of IP to use for all addresses. Options are:
   * IPVersion.any, IPVersion.v4, and IPVersion.v6
   *
   * The multicastGroupIP will use to 225.225.225.225 for IPVersion.v4 or
   * IPVersion.any and will use FF02::FB for IPVersion.v6
   *
   * If you enable discovery, you should provide a [DeviceDiscoveryListener]
   * option to receive connection and disconnection events.
   *
   * You should normally provide a [ConnectionListener] to receive events on
   * connection and disconnection.
   */
  Host({String name, int multicastPort, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener}){
    _name = name?.replaceAll("|", "_") ?? "<Unknown Host>";
    _multicastPort = multicastPort ?? DEFAULT_MULTICAST_PORT;
    _ipVersion = ipVersion ?? IPVersion.any;
    _multicastGroupIP = (_ipVersion == IPVersion.any || _ipVersion == IPVersion.v4 ?
          DEFAULT_MULTICAST_GROUP_IPV4 : DEFAULT_MULTICAST_GROUP_IPV6);
    _discoveryListener = deviceDiscoveryListener;
    _connectionListener = connectionListener;
    _discoveredDevices = Set();
  }

  Future<bool> _multicastConnect(int port) async{
    try {
      _multicastSocket = await RawDatagramSocket.bind(
          _ipVersion == IPVersion.any ? InternetAddressType.any :
          _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
          InternetAddress.anyIPv6,
          port, // _multicastPort or 0
          reuseAddress: true,
          reusePort: false)
        ..broadcastEnabled = true
        ..readEventsEnabled = true;

      return true;
    }
    catch(error, stackTrace){
      _discoveryListener?.onClose(true, error, stackTrace);
      return false;
    }
  }

  /// Hosts can send messages to other devices using the internal socket
  /// contained in the Device.
  ///
  /// Messages can mostly only be sent to Devices received after
  /// an event is received from [ConnectionListener.onConnected] which is triggered
  /// when a Client uses [Client.connectTo] to initiate a connection. You cannot
  /// send messages to Devices received in the Discovery phases from
  /// [DeviceDiscoveryListener.onDiscovery] or [DeviceDiscoveryListener.onAdvertisement].
  /// On the Server can send unreliable broadcast messages to the multicast
  /// group by using [Server.broadcast].
  ///
  /// When [ignoreIfNotConnected] is set to true, If the device is not connected,
  /// it will be silently ignore. If however the value is false which is the
  /// default, an Exception will be thrown.
  send(Packet packet, Device device, {bool ignoreIfNotConnected = false}) async{
    try {
      // check if we have a socket for the device
      if (device.connected) {
        if (packet.isStream) {
          await device._socket.addStream(packet.stream);
          await device._socket.flush();
        }
        else {
          await device._socket.add(packet.bytes);
          await device._socket.flush();
        }
      }
      else if (!ignoreIfNotConnected)
        throw "Cannot send message. There is no socket connection to this Device.";
    }
    catch(ignored){}
  }


  /// Get the first IP address we find.
  Future<void> _findFirstIPAddress() async {
    _ipAddress = (await (_ipVersion == IPVersion.any ? ipAddresses :
        _ipVersion == IPVersion.v4 ? ipv4Addresses : ipv6Addresses)).first;
  }


  /// If this device is ready to
  Future<bool> get ready => _readyCompleter.future;

  /// Get the detected IP address
  String get ipAddress => _ipAddress;

  /// Get the multicast Group IP Address
  String get multicastIPAddress => _multicastGroupIP;

  /// Get the multicast port
  int get multicastPort => _multicastPort;

  /// Get all IP addresses for all IP versions
  Future<Iterable<String>> get ipAddresses async => _getAddresses(InternetAddressType.any);
  /// Get all IP addresses for IPv4
  Future<Iterable<String>> get ipv4Addresses async => _getAddresses(InternetAddressType.IPv4);
  /// Get all IP addresses for IPv6
  Future<Iterable<String>> get ipv6Addresses async => _getAddresses(InternetAddressType.IPv6);

  Future<Iterable<Map<NetworkInterface, Iterable<InternetAddress>>>> get interfaceAddresses async{
    List<Map<NetworkInterface, Iterable<InternetAddress>>> addresses = [];

    for(NetworkInterface interface in await interfaces){
      Map<NetworkInterface, Iterable<InternetAddress>> map = {};
      map[interface] = interface.addresses;
      addresses.add(map);
    }

    return addresses;
  }

  /// Get all IP addresses for specified IP version.
  /// IP addresses are not cached because they could potentially be stale.
  Future<Iterable<String>> _getAddresses(InternetAddressType type) async{
    final interfaces = await NetworkInterface.list(includeLoopback: false,
        includeLinkLocal: true, type: type);

    print("Found ${interfaces.length} interface(s)");

    return interfaces.where((interface) => interface != null)
        .expand((interface) => interface.addresses)
        .map((address) => address.address);
  }

  Future<List<NetworkInterface>> get interfaces{
    InternetAddressType type = InternetAddressType.any;
    if( _ipVersion == IPVersion.v4 )
      type = InternetAddressType.IPv4;
    else if( _ipVersion == IPVersion.v6 )
      type = InternetAddressType.IPv6;

    return NetworkInterface.list(includeLoopback: false, includeLinkLocal: true,
        type: type);
  }

  /// Set the name of this Host. Useful for identification purposes. This will be
  /// sent to all other communicating devices as the name of the host
  set name (String name) => _name = name;
  /// Get the name of this Host. Must have been set using the set property or constructor
  String get name => _name;

  Future<void> disconnect();
}

/// The supported IP version to use
enum IPVersion{
  any, v4, v6
}
