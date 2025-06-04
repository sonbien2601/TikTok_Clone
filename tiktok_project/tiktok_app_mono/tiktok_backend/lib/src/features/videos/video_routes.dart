// tiktok_backend/lib/src/features/videos/video_routes.dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/video_controller.dart';

Router createVideoRoutes() {
  final router = Router();
  
  // Video upload và feed routes
  router.post('/upload', VideoController.uploadVideoHandler);
  router.get('/feed', VideoController.getFeedVideosHandler);
  
  // Like/Unlike video routes - Sửa pattern để khớp với request
  router.post('/<videoId>/like', VideoController.toggleLikeVideoHandler);
  router.post('/<videoId>/save', VideoController.toggleSaveVideoHandler);
  
  // Thêm OPTIONS handler cho CORS preflight requests
  router.options('/<videoId>/like', (Request request) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
  });
  
  router.options('/<videoId>/save', (Request request) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
  });
  
  // Thêm route debug để kiểm tra routing
  router.get('/debug/<videoId>/like', (Request request) async {
    final videoId = request.params['videoId'];
    return Response.ok('Debug: Like route for video $videoId is working');
  });
  
  router.get('/debug/<videoId>/save', (Request request) async {
    final videoId = request.params['videoId'];
    return Response.ok('Debug: Save route for video $videoId is working');
  });
  
  return router;
}