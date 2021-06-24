import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart' show load, env;

class _JWT {
  const _JWT();

  Future<Map<String, dynamic>> renewAccessToken(String refresh_token) async {
    var res = await verifyingRefreshToken(refresh_token);

    if (res['error'] == null) {
      var access_token = buildAccessToken(res['payload']['id']);

      return {
        'error': null,
        'access_token': access_token,
      };
    } else {
      return {
        'error': res['error'],
        'access_token': null,
      };
    }
  }

  Future<Map<String, dynamic>> verifyingRefreshToken(
    String refresh_token,
  ) async {
    load();

    var splitAuthorization = refresh_token.split(' ');

    if (splitAuthorization.length != 2) {
      return {
        'error': 'invalid or malformed access token',
        'payload': null,
      };
    }

    var splitToken = splitAuthorization[1].split('.');

    if (splitToken.length != 3) {
      return {
        'error': 'invalid or malformed jsonwebtoken',
        'payload': null,
      };
    }

    var header64 = splitToken[0];
    var payload64 = splitToken[1];
    var sign64 = splitToken[2];

    final hmac = Hmac(sha256, utf8.encode(env['refresh_token']!));

    final digest = hmac.convert(utf8.encode('$header64.$payload64'));

    final globalSign = base64Url.encode(digest.bytes).replaceAll('=', '');

    if (globalSign == sign64) {
      Map<String, dynamic> payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(payload64))));

      if (DateTime.now().toUtc().millisecondsSinceEpoch < payload['exp']) {
        return {
          'error': null,
          'payload': payload,
        };
      } else {
        return {
          'error': 'jsonwebtoken is expired',
          'payload': null,
        };
      }
    } else {
      return {
        'error': 'invalid jsonwebtoken',
        'payload': null,
      };
    }
  }

  Future<Map<String, dynamic>> verifyingAccessToken(String access_token) async {
    load();

    var splitAuthorization = access_token.split(' ');

    if (splitAuthorization.length != 2) {
      return {
        'error': 'invalid or malformed access token',
        'payload': null,
      };
    }

    var splitToken = splitAuthorization[1].split('.');

    if (splitToken.length != 3) {
      return {
        'error': 'invalid or malformed jsonwebtoken',
        'payload': null,
      };
    }

    var header64 = splitToken[0];
    var payload64 = splitToken[1];
    var sign64 = splitToken[2];

    final hmac = Hmac(sha256, utf8.encode(env['access_token']!));

    final digest = hmac.convert(utf8.encode('$header64.$payload64'));

    final globalSign = base64Url.encode(digest.bytes).replaceAll('=', '');

    if (globalSign == sign64) {
      Map<String, dynamic> payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(payload64))));

      if (DateTime.now().toUtc().millisecondsSinceEpoch < payload['exp']) {
        return {
          'error': null,
          'payload': payload,
        };
      } else {
        return {
          'error': 'jsonwebtoken is expired',
          'payload': null,
        };
      }
    } else {
      return {
        'error': 'invalid jsonwebtoken',
        'payload': null,
      };
    }
  }

  String buildRefreshToken(String id) {
    load();

    final header = {'typ': 'JWT', 'alg': 'HS256'};

    final headerJson = json.encode(header);

    final header64 = base64Url.encode(utf8.encode(headerJson));

    final payload = {
      'iss': 'Mobilepad',
      'id': id,
      'iat': DateTime.now().toUtc().millisecondsSinceEpoch,
      'exp': DateTime.now().toUtc().millisecondsSinceEpoch +
          Duration(days: 30).inMilliseconds,
    };

    final payloadJson = json.encode(payload);

    final payload64 =
        base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');

    final hmac = Hmac(sha256, utf8.encode(env['refresh_token']!));

    final digest = hmac.convert(utf8.encode('$header64.$payload64'));

    final sign = base64Url.encode(digest.bytes).replaceAll('=', '');

    return '$header64.$payload64.$sign';
  }

  String buildAccessToken(String id) {
    load();

    final header = {'typ': 'JWT', 'alg': 'HS256'};

    final headerJson = json.encode(header);

    final header64 = base64Url.encode(utf8.encode(headerJson));

    final payload = {
      'iss': 'Mobilepad',
      'id': id,
      'iat': DateTime.now().toUtc().millisecondsSinceEpoch,
      'exp': DateTime.now().toUtc().millisecondsSinceEpoch +
          Duration(hours: 1).inMilliseconds,
    };

    final payloadJson = json.encode(payload);

    final payload64 =
        base64Url.encode(utf8.encode(payloadJson)).replaceAll('=', '');

    final hmac = Hmac(sha256, utf8.encode(env['access_token']!));

    final digest = hmac.convert(utf8.encode('$header64.$payload64'));

    final sign = base64Url.encode(digest.bytes).replaceAll('=', '');

    return '$header64.$payload64.$sign';
  }
}

const jwt = _JWT();
