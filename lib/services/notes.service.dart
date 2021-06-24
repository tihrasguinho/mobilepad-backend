import 'dart:async';
import 'dart:convert';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:mobilepad/functions/encrypt.function.dart';
import 'package:mobilepad/functions/jwt.function.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'notes.service.g.dart';

class NotesService {
  final headers = {'Content-Type': 'application/json'};
  final PostgreSQLConnection connection;

  NotesService(this.connection);

  @Route.get('/')
  FutureOr<Response> defaultRoute(Request request) => Response.ok(
        json.encode({'message': 'nothing to see here'}),
        headers: headers,
      );

  @Route.delete('/delete_all')
  FutureOr<Response> deleteAllNotes(Request request) async {
    final authorization = request.headers['Authorization'];

    if (authorization == null) {
      return Response(
        400,
        body: json.encode({
          'error': 'access token not provided',
          'notes': null,
        }),
        headers: headers,
      );
    }

    final res = await jwt.verifyingAccessToken(authorization);

    if (res['error'] != null) {
      return Response(
        401,
        body: json.encode({
          'error': res['error'],
          'note': null,
        }),
        headers: headers,
      );
    }

    try {
      if (connection.isClosed) await connection.open();

      final delete = await connection.mappedResultsQuery(
        'delete from notes where owner_id = @id returning id',
        substitutionValues: {
          'id': res['payload']['id'],
        },
      );

      if (delete.isEmpty) {
        return Response(
          404,
          body: json.encode({
            'error': 'no notes found',
            'message': null,
          }),
          headers: headers,
        );
      }

      return Response(
        200,
        body: json.encode({
          'error': null,
          'message': '${delete.length} notes have been deleted',
        }),
        headers: headers,
      );
    } on PostgreSQLException catch (e) {
      return Response(
        400,
        body: json.encode({
          'error': e.message,
          'message': null,
        }),
        headers: headers,
      );
    } on Exception catch (e) {
      return Response(
        400,
        body: json.encode({
          'error': e.toString(),
          'message': null,
        }),
        headers: headers,
      );
    }
  }

  @Route.delete('/delete/<id>')
  FutureOr<Response> deleteNote(Request request, String id) async {
    final authorization = request.headers['Authorization'];

    if (authorization == null) {
      return Response(
        400,
        body: json.encode({
          'error': 'access token not provided',
          'notes': null,
        }),
        headers: headers,
      );
    }

    final res = await jwt.verifyingAccessToken(authorization);

    if (res['error'] != null) {
      return Response(
        401,
        body: json.encode({
          'error': res['error'],
          'note': null,
        }),
        headers: headers,
      );
    }

    try {
      if (connection.isClosed) await connection.open();

      final delete = await connection.mappedResultsQuery(
        'delete from notes where id = @id returning *',
        substitutionValues: {
          'id': id,
        },
      );

      if (delete.isEmpty) {
        return Response(
          404,
          body: json.encode({
            'error': 'note with this id not found',
            'notes': null,
          }),
          headers: headers,
        );
      }

      final decrypted = crypt.decryptData64(
          delete.first['notes']!['note'], dotenv.env['data_encrypt'] as String);

      return Response(
        200,
        body: json.encode({
          'error': null,
          'note': {
            ...delete.first['notes']!,
            'note': decrypted,
            'created_at': (delete.first['notes']!['created_at'] as DateTime)
                .toLocal()
                .millisecondsSinceEpoch,
            'updated_at': (delete.first['notes']!['updated_at'] as DateTime)
                .toLocal()
                .millisecondsSinceEpoch,
          },
        }),
        headers: headers,
      );
    } on PostgreSQLException catch (e) {
      return Response(
        400,
        body: json.encode({
          'error': e.message,
          'notes': null,
        }),
        headers: headers,
      );
    } on Exception catch (e) {
      return Response(
        400,
        body: json.encode({
          'error': e.toString(),
          'notes': null,
        }),
        headers: headers,
      );
    }
  }

  @Route.put('/update/<id>')
  FutureOr<Response> updateNote(Request request, String id) async {
    final authorization = request.headers['Authorization'];

    if (authorization == null) {
      return Response(
        400,
        body: json.encode({
          'error': 'access token not provided',
          'notes': null,
        }),
        headers: headers,
      );
    }

    final res = await jwt.verifyingAccessToken(authorization);

    if (res['error'] != null) {
      return Response(
        401,
        body: json.encode({
          'error': res['error'],
          'notes': null,
        }),
        headers: headers,
      );
    }

    final body =
        json.decode(await request.readAsString()) as Map<String, dynamic>;

    if (!body.containsKey('note')) {
      return Response(
        400,
        body: json.encode({
          'error': 'note information not provided',
          'note': null,
        }),
        headers: headers,
      );
    }

    final note = body['note'] as Map<String, dynamic>;

    if (note.containsKey('title') && note.containsKey('note')) {
      try {
        if (connection.isClosed) await connection.open();

        dotenv.load();

        final encrypted =
            crypt.encryptData64(note, dotenv.env['data_encrypt'] as String);

        final update = await connection.mappedResultsQuery(
          'update notes set note = @note, updated_at = current_timestamp where id = @id returning *',
          substitutionValues: {
            'note': encrypted,
            'id': id,
          },
        );

        if (update.isEmpty) {
          return Response.forbidden(
            json.encode({
              'error': 'note with this id not found',
              'notes': null,
            }),
            headers: headers,
          );
        }

        return Response(
          200,
          body: json.encode({
            'error': null,
            'note': {
              ...update.first['notes']!,
              'note': note,
              'created_at': (update.first['notes']!['created_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
              'updated_at': (update.first['notes']!['updated_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
            },
          }),
          headers: headers,
        );
      } on PostgreSQLException catch (e) {
        return Response(
          400,
          body: json.encode({
            'error': e.message,
            'data': null,
          }),
          headers: headers,
        );
      } on Exception catch (e) {
        return Response(
          400,
          body: json.encode({
            'error': e.toString(),
            'data': null,
          }),
          headers: headers,
        );
      }
    } else {
      return Response(
        400,
        body: json.encode({
          'error': 'invalid or malformed note',
          'data': null,
        }),
        headers: headers,
      );
    }
  }

  @Route.get('/all')
  FutureOr<Response> getNotes(Request request) async {
    final authorization = request.headers['Authorization'];

    if (authorization == null) {
      return Response(
        400,
        body: json.encode({
          'error': 'access token not provided',
          'notes': [],
        }),
        headers: headers,
      );
    }

    final res = await jwt.verifyingAccessToken(authorization);

    if (res['error'] != null) {
      return Response(
        401,
        body: json.encode({
          'error': res['error'],
          'notes': [],
        }),
        headers: headers,
      );
    }

    if (connection.isClosed) await connection.open();

    dotenv.load();

    final query = await connection.mappedResultsQuery(
      'select * from notes where owner_id = @id',
      substitutionValues: {
        'id': res['payload']['id'],
      },
    );

    if (query.isEmpty) {
      return Response(
        404,
        body: json.encode({
          'error': null,
          'notes': [],
        }),
        headers: headers,
      );
    }

    final notes = query.map((e) {
      var data = crypt.decryptData64(
          e['notes']!['note'], dotenv.env['data_encrypt'] as String);

      return {
        'id': e['notes']!['id'],
        'note': data,
        'created_at': (e['notes']!['created_at'] as DateTime)
            .toLocal()
            .millisecondsSinceEpoch,
        'updated_at': (e['notes']!['updated_at'] as DateTime)
            .toLocal()
            .millisecondsSinceEpoch,
        'owner_id': e['notes']!['owner_id']
      };
    }).toList();

    return Response(
      200,
      body: json.encode({
        'error': null,
        'notes': notes,
      }),
      headers: headers,
    );
  }

  @Route.post('/create')
  FutureOr<Response> createNote(Request request) async {
    final authorization = request.headers['Authorization'];

    if (authorization == null) {
      return Response(
        400,
        body: json.encode({
          'error': 'access token not provided',
          'notes': [],
        }),
        headers: headers,
      );
    }

    final res = await jwt.verifyingAccessToken(authorization);

    if (res['error'] != null) {
      return Response(
        401,
        body: json.encode({
          'error': res['error'],
          'data': null,
        }),
        headers: headers,
      );
    }

    final body =
        json.decode(await request.readAsString()) as Map<String, dynamic>;

    if (!body.containsKey('note')) {
      return Response(
        404,
        body: json.encode({
          'error': 'note not provided',
          'data': null,
        }),
        headers: headers,
      );
    }

    var mNote = body['note'] as Map<String, dynamic>;

    if (mNote.containsKey('title') && mNote.containsKey('note')) {
      try {
        if (connection.isClosed) await connection.open();

        dotenv.load();

        var note = <String, dynamic>{
          'title': mNote['title'],
          'note': mNote['note'],
        };

        final note64 =
            crypt.encryptData64(note, dotenv.env['data_encrypt'] as String);

        var insert = await connection.mappedResultsQuery(
          'insert into notes (note, owner_id) values (@note, @owner_id) returning *',
          substitutionValues: {
            'note': note64,
            'owner_id': res['payload']['id'],
          },
        );

        return Response(
          200,
          body: json.encode({
            'error': null,
            'data': {
              'id': insert.first['notes']!['id'],
              'note': insert.first['notes']!['note'],
              'created_at': (insert.first['notes']!['created_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
              'updated_at': (insert.first['notes']!['updated_at'] as DateTime)
                  .toLocal()
                  .millisecondsSinceEpoch,
              'owner_id': insert.first['notes']!['owner_id'],
            },
          }),
          headers: headers,
        );
      } on PostgreSQLException catch (e) {
        return Response(
          400,
          body: json.encode({
            'error': e.message,
            'data': null,
          }),
          headers: headers,
        );
      } on Exception catch (e) {
        return Response(
          400,
          body: json.encode({
            'error': e.toString(),
            'data': null,
          }),
          headers: headers,
        );
      }
    } else {
      return Response(
        400,
        body: json.encode({
          'error': 'invalid or malformed note',
          'data': null,
        }),
        headers: headers,
      );
    }
  }

  Router get router => _$NotesServiceRouter(this);
}
