// tiktok_backend/lib/src/features/users/user_routes.dart
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/auth_controller.dart';    // Import AuthController
import 'controllers/profile_controller.dart'; // Import ProfileController

// Thay vì class UserApi, chúng ta có thể dùng một hàm để build router cho user
// Hoặc bạn vẫn có thể giữ class UserApi và gọi các phương thức static từ controller

// Cách 1: Dùng hàm để build router (đơn giản hơn)
Router createUserRoutes() {
  final router = Router();

  // Auth routes
  router.post('/register', AuthController.registerHandler);
  router.post('/login', AuthController.loginHandler);

  // Profile routes
  router.get('/<userId>', ProfileController.getUserProfileHandler);
  // router.put('/<userId>', ProfileController.updateUserProfileHandler); // Ví dụ cho API cập nhật

  // Route test (nếu bạn vẫn muốn giữ)
  router.get('/test-user-api', (Request request) {
    print('[UserRoutes] /test-user-api route hit!');
    return Response.ok('User API test route in new structure is working!');
  });
  
  return router;
}

/* // Cách 2: Vẫn dùng class UserApi (nếu bạn thích)
class UserApi {
  Router get router {
    final router = Router();

    // Auth routes
    router.post('/register', AuthController.registerHandler);
    router.post('/login', AuthController.loginHandler);

    // Profile routes
    router.get('/<userId>', ProfileController.getUserProfileHandler);

    // Test route
    router.get('/test-user-api', (Request request) {
      print('[UserApi] /test-user-api route hit!');
      return Response.ok('User API test route in UserApi class is working!');
    });
    
    return router;
  }
}
*/