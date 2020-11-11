part of 'host.dart';

class Client extends Host{
  Socket _socket;
  bool _connected;

  Client({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener})
      : super(name: name, multicastPort: multicastPort, multicastGroupIP : multicastGroupIP, ipVersion: ipVersion,
          deviceDiscoveryListener : deviceDiscoveryListener, connectionListener: connectionListener){
    _connected = false;
    _init();
  }

  Future<void> _init(){
    return _findFirstIPAddress()
        .then<void>((_){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(true);
        }).catchError((e){
          if( !_readyCompleter.isCompleted )
            _readyCompleter.complete(false);
        });
  }

  /// client searches for AP hosts (Servers)
  Future<void> discoverHosts() async{
    _multicastSocket = await RawDatagramSocket.bind(
        _ipVersion == IPVersion.any ? InternetAddressType.any :
        _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
        InternetAddress.anyIPv6,
        _multicastPort, // _multicastPort or 0
        reusePort: true)
      ..broadcastEnabled = true;
    _multicastSocket.readEventsEnabled = true;
    _multicastSocket.joinMulticast( InternetAddress( _multicastGroupIP ) );
    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>().startsWith("PING")) {
          //TODO send the name of the device along side the response
          _multicastSocket.send(
            Packet.from("PONG|$name").bytes,
            datagram.address,
            datagram.port,
          );

          List<String> parts = Packet.from(datagram.data).as<String>().split("|");
          Device device = new Device.from(
            ip: datagram.address.address,
            port: int.tryParse(parts[2]),
            name: parts[1]
          );

          if( !_discoveredDevices.contains(device) ){
            _discoveredDevices.add(device);
            _discoveryListener?.onDiscovery(device, _discoveredDevices);
          }
        }
      }
    }, onDone: (){
      //TODO
      print("Multicast Done in Client");
    }, onError: (e){
      //TODO
      print("Multicast Error in Client: $e");
    });
  }

  /// The client can connect to the Server that is already listening for connection.
  /// [ipAddress] is the IP to use in connecting to the server if the default detected
  /// one is not the interface you want to use.
  /// [ipAddress] is not validated for correctness or if really it is owned by this Device
  /// All IP addresses for host can be obtained using the ipAddresses property
  void connectTo(Device device, {String ipAddress}) async{
    // Disconnect from Server if we have already previously connected
    await _disconnectFromServer();

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
    }, onDone: (){
      _socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device);
      _connected = false;
      print("Socket Done in Client");
    }, onError: (e){
      _socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device);
      _connected = false;
      print("Socket Error in Client: $e");
    }, cancelOnError: true);
  }

  bool get connected => _connected;

  @override
  void disconnect() async{
    _multicastSocket?.leaveMulticast(InternetAddress( _multicastGroupIP ));
    _multicastSocket?.close();
    _disconnectFromServer();
  }

  void _disconnectFromServer() async{
    await _socket?.close();
    _socket?.destroy();
    _connected = false;
  }
}