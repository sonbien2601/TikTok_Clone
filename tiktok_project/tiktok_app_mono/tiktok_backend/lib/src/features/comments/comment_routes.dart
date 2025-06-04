// tiktok_backend/lib/src/features/comments/comment_routes.dart
import 'package:shelf_router/shelf_router.dart';
import 'controllers/comment_controller.dart';

Router createCommentRoutes() {
  final router = Router();
  router.post('/video/<videoId>', CommentController.addCommentHandler);
  router.get('/video/<videoId>', CommentController.getVideoCommentsHandler);
  return router;
}