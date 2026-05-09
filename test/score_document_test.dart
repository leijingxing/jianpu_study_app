import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/data/models.dart';

void main() {
  test('parses lyrics from the line after the lyrics marker', () {
    final document = ScoreDocument.parse('''
title:女儿情
composer:啊华
lyricist:杨清
| 4/4 0 0 5,_ 6,_ | 1. 2_ (3_ 7,_) |
lyrics:
+1 +1 鸳 鸯 双 栖 蝶
lyrics:
+1 +1 +1 +1 +1 +1 +1
''');

    expect(document.notation, hasLength(1));
    expect(document.notation.single, contains('5,_'));
    expect(document.lyrics, ['', '', '鸳', '鸯', '双', '栖', '蝶']);
  });
}
