import 'package:network_data_transfer/host.dart';
import 'package:test/test.dart';

void main(){
  group("Packet can safely encode and decode", (){
    test("Strings", (){
      final value = "Hello world!";
      Packet packet = Packet.from(value);
      expect(packet.asString(), equals(value));
    });

    test("Integers", (){
      final value = 98;
      Packet packet = Packet.from(value);
      expect(packet.as<int>(), equals(value));
    });

    test("Boolean", (){
      bool value = false;
      Packet packet = Packet.from(value);
      expect(packet.as<bool>(), equals(value));

      value = true;
      packet = Packet.from(value);
      expect(packet.as<bool>(), equals(value));
    });

    test("List of strings", (){
      final value = <String>["How", "are", "you", "doing?"];
      Packet packet = Packet.from(value);
      // check that the length is the same
      expect(packet.asList(), allOf([
        isList,
        hasLength(value.length)
      ]));
      expect(packet.as<List>().first as String, equals(value.first));
      expect(packet.as<List<dynamic>>().last as String, equals(value.last));
    });

    test("Map of String keys and Complex object", (){
      final value = <String, dynamic>{"name": "Richboy",
        "age": 24, "temperature": 34.5};
      Packet packet = Packet.from(value);
      expect(packet.asMap(), allOf([
        isMap,
        hasLength(3)
      ]));
      expect(packet.asMap<String, dynamic>()["name"] as String, equals("Richboy"));
      expect(packet.asMap()["age"] as int, equals(24));
      expect(packet.asMap()["temperature"] as double, equals(34.5));
      expect(packet.asMap()["notexist"], isNull);

      Map<String, dynamic> map = packet.as<Map<String, dynamic>>();
      print(map);
    });
  });

  test("Packet can add and return bytes safely", (){
    Packet packet = new Packet();
    packet.addAll("Hello".codeUnits);
    packet.addAll(" World".codeUnits);
    expect(packet.asString(), equals("Hello World"));
  });
}