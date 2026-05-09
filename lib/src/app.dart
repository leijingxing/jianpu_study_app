import 'package:flutter/material.dart';

import 'home/home_page.dart';
import 'theme/app_theme.dart';

class JianpuStudyApp extends StatelessWidget {
  const JianpuStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简谱学习',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomePage(),
    );
  }
}
