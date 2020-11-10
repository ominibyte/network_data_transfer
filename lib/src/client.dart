part of 'host.dart';

class Client extends Host{
  Socket _socket;
  bool _connected;

  Client({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener})
      : super(multicastPort: multicastPort, multicastGroupIP : multicastGroupIP, ipVersion: ipVersion,
          deviceDiscoveryListener : deviceDiscoveryListener, name: name){
    _connected = false;
    _findFirstIPAddress().then<void>((_){
      if( !_readyCompleter.isCompleted )
        _readyCompleter.complete(true);
    });
  }

  /// client searches for AP hosts (Servers)
  Future<void> discoverHosts() async{
    _multicastSocket = await RawDatagramSocket.bind(
        _ipVersion == IPVersion.any ? InternetAddressType.any :
        _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
        InternetAddress.anyIPv6, 0) // _port
      ..broadcastEnabled = true;
    _multicastSocket.readEventsEnabled = true;
    _multicastSocket.joinMulticast( InternetAddress( _multicastGroupIP ) );
    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>() == "PING") {
          //TODO send the name of the device along side the response
          _multicastSocket.send(
            Packet.from("PONG").bytes,
            datagram.address,
            datagram.port,
          );

          Device device = new Device(datagram.address.address, datagram.port);
          if( !_discoveredDevices.contains(device) ){
            _discoveredDevices.add(device);
            _discoveryListener?.onDiscovery(device, _discoveredDevices);
          }
        }
      }
    }, onDone: (){
      //TODO
    }, onError: (){
      //TODO
    });
  }

  /// The client can connect to the Server that is already listening for connection.
  /// @ipAddress is the IP to use in connecting to the server.
  /// All IP addresses for host can be obtained using the ipAddresses property
  void connectTo(Device device, {String ipAddress}) async{
    // Use the detected IP address to connect to the server
    _socket = await Socket.connect(device.ip, device.port, sourceAddress: ipAddress ?? _ipAddress);
    if( _socket == null )
      throw "Could not connect to the Server at ${device.ip}:${device.port}. Please try again later.";
    _connected = true;
    device._isConnected = true;
    device._socket = _socket;
    // fire connection listener
    _connectionListener?.onConnected(device);

    _socket.listen((event) {
      _connectionListener?.onMessage(Packet.fromBytes(event), device);
    }, onError: (e){
      _socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device);
      _connected = false;
    }, cancelOnError: true);
  }

  @override
  void disconnect() async{
    _multicastSocket?.leaveMulticast(InternetAddress( _multicastGroupIP ));
    _multicastSocket?.close();
    await _socket?.close();
    _socket.destroy();
    _connected = false;
  }
}