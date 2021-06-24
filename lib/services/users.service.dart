import 'dart:async';

import 'package:mobilepad/functions/jwt.function.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'users.service.g.dart';

class UsersService {
  @Route.get('/')
  FutureOr<Response> getAll(Request request) async {
    // final body =
    //     jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final headers = request.headers['Authorization'];

    print(await jwt.verifyingAccessToken(headers!));

    return Response.ok('body');
  }

  Router get router => _$UsersServiceRouter(this);
}
