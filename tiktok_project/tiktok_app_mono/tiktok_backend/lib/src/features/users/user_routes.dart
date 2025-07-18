// Sửa lại user_routes.dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/auth_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/donate_history_controller.dart';
import 'controllers/upload_controller.dart';

Router createUserRoutes() {
  final router = Router();

  print('[UserRoutes] Creating user routes with profile features...');

  // Auth routes
  router.post('/register', AuthController.registerHandler);
  router.post('/login', AuthController.loginHandler);

  // Profile routes - Basic user info
  router.get('/<userId>', ProfileController.getUserProfileHandler);
  router.put('/<userId>', ProfileController.updateUserProfileHandler);

  // Profile routes - User content
  router.get('/<userId>/liked-videos', ProfileController.getLikedVideosHandler);
  router.get('/<userId>/saved-videos', ProfileController.getSavedVideosHandler);
  router.get('/<userId>/videos', ProfileController.getUserVideosHandler);

  // Donate routes - Sửa lại đúng route
  router.post('/donate', DonateHistoryController.createDonateHandler);
  router.get('/<userId>/donate-history', DonateHistoryController.getDonateHistoryByUserHandler);
  router.get('/<userId>/received-donate-history', DonateHistoryController.getReceivedDonateHistoryHandler);

  // Upload image (QR, proof)
  router.post('/upload-image', UploadController.uploadImageHandler);

  // Test route
  router.get('/test-user-api', (Request request) {
    print('[UserRoutes] /test-user-api route hit!');
    return Response.ok('User API test route with profile features is working!');
  });

  // Debug route
  router.get('/debug/routes', (Request request) {
    return Response.ok('''
User API Routes:
- POST /api/users/register - Register new user
- POST /api/users/login - Login user
- GET /api/users/{userId} - Get user profile
- PUT /api/users/{userId} - Update user profile
- GET /api/users/{userId}/liked-videos - Get user's liked videos
- GET /api/users/{userId}/saved-videos - Get user's saved videos  
- GET /api/users/{userId}/videos - Get user's own videos
- POST /api/users/donate - Create donate
- GET /api/users/{userId}/donate-history - Get user's donate history (sent)
- GET /api/users/{userId}/received-donate-history - Get user's received donate history
- POST /api/users/upload-image - Upload image
- GET /api/users/test-user-api - Test route
- GET /api/users/debug/routes - This debug info

Example URLs:
- GET /api/users/682ead1be4f819a1b0000000
- PUT /api/users/682ead1be4f819a1b0000000
- GET /api/users/682ead1be4f819a1b0000000/liked-videos?page=1&limit=20
- GET /api/users/682ead1be4f819a1b0000000/saved-videos?page=1&limit=20
- GET /api/users/682ead1be4f819a1b0000000/videos?page=1&limit=20
- GET /api/users/682ead1be4f819a1b0000000/donate-history
- GET /api/users/682ead1be4f819a1b0000000/received-donate-history
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

  print('[UserRoutes] ✅ User routes created with profile features');
  return router;
}