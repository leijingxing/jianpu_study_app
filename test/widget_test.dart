import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/main.dart';

void main() {
  testWidgets('shows the study app shell', (tester) async {
    await tester.pumpWidget(const JianpuStudyApp());
    await tester.pump();

    expect(find.text('轻谱'), findsOneWidget);
    expect(find.text('动态谱'), findsOneWidget);
    expect(find.text('图片谱'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
  });
}
