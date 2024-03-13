import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

class Utils {
  /// 当前项目地址（不包含test文件夹)
  static String currentPath = path.join(Platform.environment['PWD']!);

  /// 截图测试时，可以传入providers来预加载图片，这样才能正确加载图片
  static Future<void> pumpWidgetWithImages(
    WidgetTester tester,
    Widget widget,
    List<ImageProvider> providers,
  ) async {
    Future<void>? precacheFuture;
    await tester.pumpWidget(
      Builder(builder: (buildContext) {
        precacheFuture = tester.runAsync(() async {
          await Future.wait([
            for (final provider in providers)
              precacheImage(
                provider,
                buildContext,
              ),
          ]);
        });
        return widget;
      }),
    );
    await precacheFuture;
  }
}
