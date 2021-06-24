// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes.service.dart';

// **************************************************************************
// ShelfRouterGenerator
// **************************************************************************

Router _$NotesServiceRouter(NotesService service) {
  final router = Router();
  router.add('GET', r'/', service.defaultRoute);
  router.add('DELETE', r'/delete_all', service.deleteAllNotes);
  router.add('DELETE', r'/delete/<id>', service.deleteNote);
  router.add('PUT', r'/update/<id>', service.updateNote);
  router.add('GET', r'/all', service.getNotes);
  router.add('POST', r'/create', service.createNote);
  return router;
}
