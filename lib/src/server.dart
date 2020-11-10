part of 'host.dart';

/// A server listens for connections and keeps a list of all the
/// connected devices
class Server extends Host{
  ServerSocket _serverSocket;
  int _socketPort;  // The port where this
  bool _running;

  Server({String name, int multicastPort, String multicastGroupIP, IPVersion ipVersion,
    DeviceDiscoveryListener deviceDiscoveryListener, ConnectionListener connectionListener,
    int serverSocketPort})
      : super(name: name, multicastPort: multicastPort, multicastGroupIP : multicastGroupIP,
        ipVersion: ipVersion, deviceDiscoveryListener : deviceDiscoveryListener){
    _socketPort = serverSocketPort ?? 0;
    // check that the port is within a valid range
    if( _socketPort != 0 ){
      assert(_socketPort > 1024);
      assert(_socketPort < 65535);
    }

    // initialize the needed params
    _init();
  }

  void _init(){
    // reset the ready completer just in case we may need to call init again on failed start
    _readyCompleter = Completer();
    _running = false;

    // First detect the IP address of the server which we will listen to
    // next, start listening for connections on the socket port
    // before enabling discovery from clients.
    _findFirstIPAddress()
        .then((_) => _listenForConnections())
        .then((_) => _enableDiscovery())
        .then<void>((_){
      if( !_readyCompleter.isCompleted )
        _readyCompleter.complete(true);
    }).catchError((){
      if( !_readyCompleter.isCompleted )
        _readyCompleter.complete(false);
    });
  }

  // server automatically listens for client incoming connections
  Future<void> _listenForConnections() async{
    _serverSocket = await ServerSocket.bind(_ipAddress, _socketPort);
    // Update the port just in case no port was specified for connection
    _socketPort = _serverSocket.port;
    _serverSocket.listen(
      _processSocket,
      onError: (e){
        _running = false;
      },
      onDone: (){
        _running = false;
      },
      cancelOnError: true
    );
  }

  // Handle the new connection
  void _processSocket(Socket socket){
    // Check if we have a device with this IP address
    Device device = new Device(socket.remoteAddress.address, socket.remotePort);
    // Inform any listener if this device is new. This means this device didn't use
    // The discovery mode for connection. The server might likely be using a static IP
    if( !_discoveredDevices.contains(device) ){
      _discoveredDevices.add(device);
      _discoveryListener?.onDiscovery(device, _discoveredDevices);
    }
    else  // get the current device from discovered devices and set the connection details
      device = _discoveredDevices.lookup(device);

    device._isConnected = true;
    device._socket = socket;
    // fire connection listener
    _connectionListener?.onConnected(device);
    
    socket.listen((event) {
      _connectionListener?.onMessage(Packet.fromBytes(event), device);
    }, onError: (e){
      socket.destroy();
      device._connected = null;
      // fire disconnection listener
      _connectionListener?.onDisconnected(device);
    }, cancelOnError: true);
  }

  Future<void> _enableDiscovery() async {
    _multicastSocket = await RawDatagramSocket.bind(
        _ipVersion == IPVersion.any ? InternetAddressType.any :
        _ipVersion == IPVersion.v4 ? InternetAddress.anyIPv4 :
        InternetAddress.anyIPv6, 0) // _port
      ..broadcastEnabled = true;
    _multicastSocket.readEventsEnabled = true;
    _multicastSocket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram datagram = _multicastSocket.receive();
        if (datagram != null && Packet.from(datagram.data).as<String>() == "PONG"){
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

    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if ( _timer.isActive ) {
        // TODO send the name of this device and the listening port for reliable
        //connection along wih the PING
        _multicastSocket.send(
          Packet.from("PING").bytes,
          InternetAddress(_multicastGroupIP),
          _port,
        );
      }
    });
  }

  /// Send a broadcast using either the multicast group for unreliable
  /// and the connected client sockets for reliable broadcast
  Future<void> broadcast(Packet packet, {bool reliable = false}) async{
    bool isReady = await ready;
    if( !isReady )
      throw "Host failed to start";
    else if( _ipAddress == null )
      throw "Unable to detect host IP address";
    else if( _multicastSocket != null && !reliable ){ // multicast broadcast
      _multicastSocket.send(
          packet.bytes,
          InternetAddress(_ipAddress.split(".").sublist(0, 3).join(".") + ".255"),
          _port
      );
    }
    else if( _serverSocket != null && reliable ){ // reliable broadcast
      //TODO send reliable broadcast using all connected client sockets
    }
  }

  bool get running => _running;

  @override
  void disconnect() async{
    _timer?.cancel();
    _multicastSocket?.close();
    await _serverSocket?.close();
    _running = false;
  }
}