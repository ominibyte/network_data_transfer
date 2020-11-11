network_data_transfer
=======

A network data transfer package using dart.

This package assumes that the devices are on the same network.

Usage
---

See test directory on how to start a Client and Server.

See `client_test.dart` below:
```dart
import 'package:network_data_transfer/src/host.dart';
import 'package:test/test.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Client client;

void main() async{
  client = Client(
    ipVersion: IPVersion.v4,
    name: "Client",
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
  );

  if(!await client.ready){
    print("Could not start on Client");
    return;
  }
  print("Client is ready. IP: ${client.ipAddress}");

  // Start discovering devices
  print("Discovering hosts...");
  client.discoverHosts();
}

class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("Server Discovery Alert: $newDevice");
    devices = allDevices;

    // Connect to Server
    client.connectTo(newDevice);
  }
}

class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Server Connected: $device");
  }

  @override
  void onDisconnected(Device device) {
    print("Server Disconnected: $device");
  }

  @override
  void onMessage(Packet packet, Device device) {
    print("Message Received from Server $device: ${packet.asString()}");
    // Send message back to this client
    Future.delayed(Duration(seconds: 1)).then((_) =>
        client.send(Packet.from(WordPair.random().asPascalCase), device)
    );
  }

}
```


See `server_test.dart` below:
```dart
import 'package:network_data_transfer/src/host.dart';
import 'package:test/test.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Server server;

void main() async{
  server = Server(
    ipVersion: IPVersion.v4,
    name: "Server",
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
  );

  if(!await server.ready){
    print("Could not connect on Server");
    return;
  }
  print("Server is ready at ${server.ipAddress}:${server.port}");
}

class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("New Client Device Alert: $newDevice");
    devices = allDevices;
  }
}

class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Device Connected to Server: $device");
    // Send a handshake to begin conversation
    server.send(Packet.from(WordPair.random().asPascalCase), device);
  }

  @override
  void onDisconnected(Device device) {
    print("Device Disconnected from Server: $device");
  }

  @override
  void onMessage(Packet packet, Device device) {
    print("Message Received from Client $device: ${packet.asString()}");
    Future.delayed(Duration(seconds: 1)).then((_) =>
        server.send(Packet.from(WordPair.random().asPascalCase), device)
    );
  }

}
```