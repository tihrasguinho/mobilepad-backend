import 'package:dotenv/dotenv.dart' show load, env;
import 'package:mobilepad/services/auth.service.dart';
import 'package:mobilepad/services/notes.service.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main(List<String> args) async {
  // load enviroment vars
  load();

  // connect to postgreSQL
  final connection = PostgreSQLConnection(
    env['pg_host'] as String,
    int.parse(env['pg_port'] as String),
    env['pg_database_name'] as String,
    username: env['pg_username'] as String,
    password: env['pg_password'] as String,
    useSSL: true,
  );

  await connection
      .open()
      .then((value) => print('postgreSQL connected!'))
      .catchError((err) => print(err));

  final app = Router();

  app.mount('/auth/', AuthService(connection).router);

  app.mount('/notes/', NotesService(connection).router);

  await io
      .serve(app, '0.0.0.0', int.parse(env['PORT'] as String))
      .then((value) => print('Server started...'));
}
