import 'dart:convert';

import 'package:encrypt/encrypt.dart';

class _Encrypt {
  const _Encrypt();

  String encryptData64(Map<String, dynamic> data, String secret) {
    final key = Key.fromUtf8(secret);

    final iv = IV.fromLength(16);

    final encrypter = Encrypter(AES(key));

    final encrypted = encrypter.encrypt(json.encode(data), iv: iv);

    return encrypted.base64;
  }

  Map<String, dynamic> decryptData64(String base64str, String secret) {
    final key = Key.fromUtf8(secret);

    final iv = IV.fromLength(16);

    final encrypter = Encrypter(AES(key));

    final decrypted = encrypter.decrypt64(base64str, iv: iv);

    return json.decode(decrypted);
  }
}

const crypt = _Encrypt();
