// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$AuthServiceRouter(AuthService service) {
  final router = Router();
  router.add('GET', r'/', service.defaultGet);
  router.add('POST', r'/refresh_token', service.renewAccessToken);
  router.add('POST', r'/sign_in', service.signIn);
  router.add('POST', r'/sign_up', service.createUser);
  return router;
}
