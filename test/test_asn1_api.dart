// Temporary file to check asn1lib API
import 'dart:typed_data';
import 'package:asn1lib/asn1lib.dart';

void main() {
  // ASN1ObjectIdentifier
  final oid = ASN1ObjectIdentifier.fromBytes(Uint8List.fromList([0x06, 0x03, 0x55, 0x04, 0x03]));
  print(oid.identifier); // String - dotted OID

  // ASN1Integer
  final asn1Int = ASN1Integer(BigInt.from(42));
  print(asn1Int.intValue); // int
  print(asn1Int.valueAsBigInteger); // BigInt

  // ASN1OctetString  
  final obj = ASN1OctetString(Uint8List.fromList([1, 2, 3]));
  Uint8List vb = obj.octets; // Uint8List
  print(vb.runtimeType);

  // ASN1Object - check valueBytes type
  final asn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x30, 0x00]));
  Uint8List vb2 = asn1Obj.valueBytes();
  print(vb2.runtimeType);
  Uint8List eb = asn1Obj.encodedBytes;
  print(eb.runtimeType);
  
  // ASN1Sequence elements type
  final seq = ASN1Sequence.fromBytes(Uint8List.fromList([0x30, 0x00]));
  List<ASN1Object> elems = seq.elements;
  print(elems.length);
  
  // ASN1UTF8String
  final utf8s = ASN1UTF8String('hello');
  String sv = utf8s.utf8StringValue;
  print(sv);
  
  // ASN1Set
  final set1 = ASN1Set();
  List<ASN1Object> setElems = set1.elements;
  print(setElems.length);
}
