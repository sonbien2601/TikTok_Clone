// tiktok_backend/lib/src/features/users/follow_routes.dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/follow_controller.dart';

Router createFollowRoutes() {
  final router = Router();

  print('[FollowRoutes] Creating follow routes...');

  // Follow/Unfollow routes
  router.post('/follow/<currentUserId>/<targetUserId>', (Request request, String currentUserId, String targetUserId) {
    return FollowController.followUserHandler(request, currentUserId, targetUserId);
  });

  router.delete('/unfollow/<currentUserId>/<targetUserId>', (Request request, String currentUserId, String targetUserId) {
    return FollowController.unfollowUserHandler(request, currentUserId, targetUserId);
  });

  // Get followers/following lists
  router.get('/followers/<userId>', FollowController.getFollowersHandler);
  router.get('/following/<userId>', FollowController.getFollowingHandler);

  // Check follow status
  router.get('/status/<currentUserId>/<targetUserId>', (Request request, String currentUserId, String targetUserId) {
    return FollowController.checkFollowStatusHandler(request, currentUserId, targetUserId);
  });

  // Test route
  router.get('/test-follow-api', (Request request) {
    print('[FollowRoutes] /test-follow-api route hit!');
    return Response.ok('Follow API test route is working!');
  });

  // Debug route
  router.get('/debug/routes', (Request request) {
    return Response.ok('''
Follow API Routes:
- POST /api/follow/follow/{currentUserId}/{targetUserId} - Follow a user
- DELETE /api/follow/unfollow/{currentUserId}/{targetUserId} - Unfollow a user  
- GET /api/follow/followers/{userId}?page=1&limit=20 - Get user's followers
- GET /api/follow/following/{userId}?page=1&limit=20 - Get user's following
- GET /api/follow/status/{currentUserId}/{targetUserId} - Check follow status
- GET /api/follow/test-follow-api - Test route
- GET /api/follow/debug/routes - This debug info

Example URLs:
- POST /api/follow/follow/682ead1be4f819a1b0000001/682ead1be4f819a1b0000002
- DELETE /api/follow/unfollow/682ead1be4f819a1b0000001/682ead1be4f819a1b0000002
- GET /api/follow/followers/682ead1be4f819a1b0000001?page=1&limit=20
- GET /api/follow/following/682ead1be4f819a1b0000001?page=1&limit=20
- GET /api/follow/status/682ead1be4f819a1b0000001/682ead1be4f819a1b0000002
''');
  });

  // CORS handlers
  router.options('/<path|.*>', (Request request) async {
    return Response.ok('', headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
      'Access-Control-Max-Age': '86400',
    });
  });

  print('[FollowRoutes] ✅ Follow routes created');
  return router;
}