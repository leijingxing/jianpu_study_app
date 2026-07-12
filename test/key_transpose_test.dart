import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/domain/music/key_transpose.dart';

void main() {
  test('rewrites jianpu token when displaying in another key', () {
    expect(transposeJianpuToken(raw: '5,_', fromKey: 'F', toKey: 'C'), '1_');
    expect(transposeJianpuToken(raw: '(3_', fromKey: 'F', toKey: 'C'), '(6_');
  });
}
