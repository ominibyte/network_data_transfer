network_data_transfer
=======

A network data transfer package using dart.

This package assumes that the devices are already on the same network.

[See the documentation here](doc/api/index.html), [or here](network_data_transfer/network_data_transfer-library.html) for more information on available classes and methods.

Usage
---

See test directory on how to start a Client and Server as well as sending files and messages.

Sample `client_test.dart` for working with Client:
```dart
import 'package:network_data_transfer/host.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Client client;

void main() async{
  client = Client(
    ipVersion: IPVersion.v4,
    name: "Client", // Optional friendly name of the Client host
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
  );

  // Wait for the Client to completely initialize
  if(!await client.ready){
    print("Could not start on Client");
    return;
  }
  print("Client is ready. IP: ${client.ipAddress}");

  // Start discovering devices
  print("Discovering hosts...");
  client.discoverHosts();
}

// Create listener for receiving advertisements and discovery alerts from the Server
class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("Server Discovery Alert: $newDevice");
    devices = allDevices;

    // Connect to Server
    client.connectTo(newDevice);
  }
  @override
  onClose(bool isError, Object error, StackTrace stackTrace){
    print("Discovery multicast socket closed");
  }

  @override
  void onAdvertisement(Device device, Packet packet) {
    print("Received ${packet.asString()} in onAdvertisement from Server.");
  }
}

class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Server Connected: $device");
  }

  @override
  void onDisconnected(Device device, bool isError, Object error, StackTrace stackTrace) {
    print("Server Disconnected: $device");
  }

  @override
  void onMessage(Packet packet, Device device) {
    print("Message Received from Server $device: ${packet.asString()}");
    // Send message back to this client
    Future.delayed(Duration(seconds: 1)).then((_) =>
        client.send(Packet.from(WordPair.random().asPascalCase), device,
            ignoreIfNotConnected: true)
    );
  }
}
```


Sample `server_test.dart` for working with a Server:
```dart
import 'dart:io';

import 'package:network_data_transfer/host.dart';
import 'package:english_words/english_words.dart';

Iterable<Device> devices;
Server server;

void main() async{
  server = Server(
    ipVersion: IPVersion.v4,
    name: "Server", // Optional friendly name of the Server host
    deviceDiscoveryListener: MyDiscoveryListener(),
    connectionListener: MyConnectionListener(),
    listenOn: useFirstFoundIP // Optional. Do not provide if you want to listen on all ip addresses
  );

  // Wait for the Server to completely initialize
  if(!await server.ready){
    print("Could not connect on Server");
    return;
  }
  print("Server is ready at ${server.ipAddress}:${server.port}");
}

// Use the first IP address we find for the first interface. 
// This is optional but can be used to choose the IP address for the correct interface
Future<String> useFirstFoundIP(Future<Iterable<Map<NetworkInterface, Iterable<InternetAddress>>>> interfaceAddresses) async{
  Iterable<Map<NetworkInterface, Iterable<InternetAddress>>> addressList = await interfaceAddresses;
  return addressList.first.values.first.first.address;
}

// Create listener for receiving discovery alerts from clients
class MyDiscoveryListener implements DeviceDiscoveryListener{
  @override
  onDiscovery(Device newDevice, Iterable<Device> allDevices) {
    print("New Client Device Alert: $newDevice");
    devices = allDevices;
  }

  @override
  onClose(bool isError, Object error, StackTrace stackTrace){
    print("Discovery multicast socket closed");
  }

  @override
  void onAdvertisement(Device device, Packet packet) {
    // Will never be used on the Server
  }
}

// Create a listener to listen for connection and disconnection as well as
// when messages arrive 
class MyConnectionListener implements ConnectionListener{
  @override
  void onConnected(Device device) {
    print("Device Connected to Server: $device");
    // Send a handshake to begin conversation
    server.send(Packet.from(WordPair.random().asPascalCase), device);
  }

  @override
  void onDisconnected(Device device, bool isError, Object error, StackTrace stackTrace) {
    print("Device Disconnected from Server: $device");
  }

  @override
  void onMessage(Packet packet, Device device) {
    print("Message Received from Client $device: ${packet.asString()}");
    Future.delayed(Duration(seconds: 1)).then((_) =>
        server.send(Packet.from(WordPair.random().asPascalCase), device,
            ignoreIfNotConnected: true)
    );
  }
}
```