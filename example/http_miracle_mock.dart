import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_miracle_mock/http_miracle_mock.dart';
import 'package:path/path.dart' as path;

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final HttpMiracleMock httpMiracleMock = HttpMiracleMock();
  final httpClient = HttpClient();

  test('test getUrl', () async {
    var url = 'https://example.com/create';
    var data = "resultGetUrl";
    var uri = Uri.parse(url);
    httpMiracleMock.open(url).reply(data);
    final request = await httpClient.getUrl(uri);
    final response = await request.close();
    var responseData = await response.transform(utf8.decoder).join();
    expect(responseData, data);
  });

  testWidgets('test image using url png', (WidgetTester tester) async {
    var data = File(path.join(currentPath, 'test', 'assets', 'test.png'));
    var url = 'http://example.com/image.png';
    httpMiracleMock.open(url).reply(data.readAsBytesSync());
    await pumpWidgetWithImages(
      tester,
      Column(
        children: [
          Container(
              child: Image.network(
            url,
            width: 100,
            height: 100,
          )),
        ],
      ),
      [NetworkImage(url)],
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('snapshots/net_work_image_1.png'),
    );
  });
}

String currentPath = path.join(Platform.environment['PWD']!);

Future<void> pumpWidgetWithImages(
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
