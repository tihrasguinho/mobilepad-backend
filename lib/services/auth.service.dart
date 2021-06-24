import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:mobilepad/functions/jwt.function.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'auth.service.g.dart';

class AuthService {
  final headers = {'Content-Type': 'application/json'};
  final PostgreSQLConnection connection;

  AuthService(this.connection);

  @Route.get('/')
  FutureOr<Response> defaultGet(Request request) =>
      Response.ok(json.encode({'message': 'nothing to see here!'}));

  @Route.post('/refresh_token')
  FutureOr<Response> renewAccessToken(Request request) async {
    var body =
        json.decode(await request.readAsString()) as Map<String, dynamic>;

    if (body.containsKey('refresh_token')) {
      var res = await jwt.renewAccessToken(body['refresh_token']);

      if (res['error'] == null) {
        return Response(
          200,
          body: json.encode({
            'error': null,
            'access_token': res['access_token'],
          }),
          headers: headers,
        );
      } else {
        return Response(
          401,
          body: json.encode({
            'error': res['error'],
            'access_token': null,
          }),
          headers: headers,
        );
      }
    } else {
      return Response(
        400,
        body: json.encode({
          'error': 'refresh token not provided',
          'access_token': null,
        }),
        headers: headers,
      );
    }
  }

  @Route.post('/sign_in')
  FutureOr<Response> signIn(Request request) async {
    var body =
        json.decode(await request.readAsString()) as Map<String, dynamic>;

    if (!body.containsKey('user')) {
      return Response(
        400,
        body: json.encode({'message': 'user information not provided!'}),
        headers: headers,
      );
    }

    var user = body['user'] as Map<String, dynamic>;

    if (user.containsKey('email') && user.containsKey('password')) {
      try {
        if (connection.isClosed) {
          await connection.open();
        }

        var map = await connection.mappedResultsQuery(
            'select * from users where email = @email',
            substitutionValues: {
              'email': user['email'],
            });

        if (map.isNotEmpty) {
          dotenv.load();

          var password = map.first['users']!['password'];

          var hmac = Hmac(sha256, utf8.encode(dotenv.env['password']!));

          var digest = hmac.convert(utf8.encode(user['password']));

          var hashed = base64Url.encode(digest.bytes);

          if (password == hashed) {
            var access_token = jwt.buildAccessToken(map.first['users']!['id']);

            var refresh_token =
                jwt.buildRefreshToken(map.first['users']!['id']);

            return Response(
              200,
              body: json.encode(
                {
                  'error': null,
                  'user': {
                    'id': map.first['users']!['id'],
                    'name': map.first['users']!['name'],
                    'username': map.first['users']!['username'],
                    'email': map.first['users']!['email'],
                    'created_at':
                        (map.first['users']!['created_at'] as DateTime)
                            .toLocal()
                            .millisecondsSinceEpoch,
                    'updated_at':
                        (map.first['users']!['updated_at'] as DateTime)
                            .toLocal()
                            .millisecondsSinceEpoch,
                  },
                  'access_token': access_token,
                  'refresh_token': refresh_token,
                },
              ),
              headers: headers,
            );
          } else {
            return Response(
              400,
              body: json.encode({
                'error': 'wrong password',
                'user': null,
              }),
              headers: headers,
            );
          }
        } else {
          return Response(
            404,
            body: json.encode({
              'error': 'user not found',
              'user': null,
            }),
            headers: headers,
          );
        }
      } on PostgreSQLException catch (e) {
        return Response(
          500,
          body: json.encode({'message': e.message}),
          headers: headers,
        );
      }
    } else {
      return Response(
        404,
        body: json.encode({'message': 'user information is invalid'}),
        headers: headers,
      );
    }
  }

  @Route.post('/sign_up')
  FutureOr<Response> createUser(Request request) async {
    var body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    if (!body.containsKey('user')) {
      return Response(
        404,
        body: json.encode({'message': 'user information not provided!'}),
        headers: headers,
      );
    }

    var user = body['user'] as Map<String, dynamic>;

    if (user.containsKey('email') &&
        user.containsKey('password') &&
        user.containsKey('name') &&
        user.containsKey('username')) {
      try {
        if (connection.isClosed) {
          await connection.open();
        }

        var map = await connection.mappedResultsQuery(
            'select id, username, email from users where (email = @email) or (username = @username)',
            substitutionValues: {
              'username': user['username'],
              'email': user['email'],
            });

        var email = map.isNotEmpty ? map.first['users']!['email'] : '';

        var username = map.isNotEmpty ? map.first['users']!['username'] : '';

        if (email == user['email']) {
          return Response(
            400,
            body: json.encode({'message': 'email is already in use'}),
            headers: headers,
          );
        }

        if (username == user['username']) {
          return Response(
            400,
            body: json.encode({'message': 'username is already in use'}),
            headers: headers,
          );
        }

        if ((user['password'] as String).length < 5) {
          return Response(
            400,
            body: json.encode({'message': 'your password is too weak'}),
            headers: headers,
          );
        }

        dotenv.load();

        var hmac = Hmac(sha256, utf8.encode(dotenv.env['password']!));

        var hashed = hmac.convert(utf8.encode(user['password']));

        user['password'] = base64Url.encode(hashed.bytes);

        var insert = await connection.mappedResultsQuery(
          'insert into users (name, username, email, password) values (@name, @username, @email, @password) returning id, created_at, updated_at',
          substitutionValues: {
            'name': user['name'],
            'username': user['username'],
            'email': user['email'],
            'password': user['password'],
          },
        );

        user.remove('password');

        var access_token = jwt.buildAccessToken(insert.first['users']!['id']);

        var refresh_token = jwt.buildRefreshToken(insert.first['users']!['id']);

        return Response(
          200,
          body: json.encode({
            'user': {
              ...user,
              'id': insert.first['users']!['id'],
              'created_at': (insert.first['users']!['created_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
              'updated_at': (insert.first['users']!['updated_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
            },
            'access_token': access_token,
            'refresh_token': refresh_token,
          }),
          headers: headers,
        );
      } on PostgreSQLException catch (e) {
        return Response(
          500,
          body: json.encode({'message': e.message}),
          headers: headers,
        );
      } catch (e) {
        return Response(
          500,
          body: json.encode({'message': e}),
          headers: headers,
        );
      }
    } else {
      return Response(
        404,
        body: json.encode({'message': 'user information is invalid'}),
        headers: headers,
      );
    }
  }

  Router get router => _$AuthServiceRouter(this);
}
