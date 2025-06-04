// tiktok_frontend/test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';

// Sửa import này để trỏ đến file app.dart của bạn
import 'package:tiktok_frontend/src/app.dart';
// Hoặc nếu bạn muốn test một trang cụ thể trực tiếp (ít phổ biến hơn cho widget test ban đầu)
// import 'package:tiktok_frontend/src/features/feed/presentation/pages/feed_page.dart';

void main() {
  testWidgets('App smoke test - checks if FeedPage AppBar title is present', (WidgetTester tester) async {
    // Build our app (widget App) and trigger a frame.
    await tester.pumpWidget(const App()); // Sửa MyApp thành App

    // Đợi một chút để widget con (FeedPage) có thể được build xong hoàn toàn, đặc biệt nếu có FutureBuilder hoặc tương tự
    await tester.pumpAndSettle();

    // Verify that the AppBar title 'TikTok' from FeedPage is present.
    // Điều này giả định rằng FeedPage là trang chủ và có AppBar với title 'TikTok'.
    expect(find.text('TikTok'), findsOneWidget);

    // Bạn có thể thêm các kiểm tra khác ở đây, ví dụ:
    // expect(find.byIcon(Icons.home), findsOneWidget); // Kiểm tra icon Home trên BottomNavigationBar
    // expect(find.byType(VideoCardPlaceholder), findsWidgets); // Kiểm tra xem có VideoCardPlaceholder nào được hiển thị không
  });
}