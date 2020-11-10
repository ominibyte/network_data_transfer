part of 'host.dart';

/// This class models the raw data that needs to be sent or received over the network.
/// and is just a wrapper around the raw bytes
class Packet{
  List<int> _bytes; // The raw bytes

  Packet(){
    _bytes = List<int>();
  }

  /// Allow Packets to be created from different data types. Supported data types are:
  /// String, numbers, Map, List, and Uint8List.
  /// Complex data types such as Map and List must be supported by jsonEncode
  factory Packet.from(dynamic data){
    Packet p = Packet();
    String content;
    if( data is Uint8List ){
      p._bytes = data.toList();
      return p;
    }
    else if( data is String )
      content = data;
    else if( data is Map || data is List )
      content = jsonEncode(data);
    else if( data is num )
      content = data.toString();
    else
      throw new Exception("Unsupported data type. Serialize to one of the supported formats");

    p._bytes = utf8.encode(content);
    return p;
  }

  /// Allow Packets to be created/copied from other bytes
  factory Packet.fromBytes(List<int> bytes){
    Packet p = Packet();
    p._bytes = bytes.sublist(0);
    return p;
  }

  add(int byte) => _bytes.add(byte);
  addAll(Iterable<int> bytes) => _bytes.addAll(bytes);

  Uint8List get bytes => Uint8List.fromList(_bytes);
  int get size => _bytes.length;

  /// Allow transformation back to popular data types
  /// For using these methods, We're assuming it is safe to transform to String

  E as<E>(){
    if( E == String )
      return asString() as E;
    else if( E.toString() == Map<String, dynamic>().runtimeType.toString() )
      return asMap() as E;
    else if( E.toString() == List<dynamic>().runtimeType.toString() )
      return asList() as E;
    else if( E == int )
      return asInt() as E;
    else if( E == double )
      return asDouble() as E;
    else if( E == num )
      return asNumber() as E;

    throw new Exception("Unsupported return type. Deserialize to one of the supported formats");
  }

  String asString(){
    return utf8.decode(_bytes.toList());
  }

  Map<String, dynamic> asMap(){
    return jsonDecode(asString());
  }

  List<dynamic> asList(){
    return jsonDecode(asString());
  }

  num asNumber(){
    return num.parse(asString());
  }

  int asInt(){
    return int.parse(asString());
  }

  double asDouble(){
    return double.parse(asString());
  }
}