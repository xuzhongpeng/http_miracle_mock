import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_miracle_mock/http_miracle_mock.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'utils.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final HttpMiracleMock httpMiracleMock = HttpMiracleMock();
  group('test image', () {
    testWidgets('test image using url png', (WidgetTester tester) async {
      var data =
          File(path.join(Utils.currentPath, 'test', 'assets', 'test.png'));
      var url = 'http://example.com/image.png';
      httpMiracleMock.open(url).reply(data.readAsBytesSync());
      await Utils.pumpWidgetWithImages(
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

    testWidgets('test image using header', (WidgetTester tester) async {
      var data =
          File(path.join(Utils.currentPath, 'test', 'assets', 'test.png'));
      var url = 'http://example.com/image';
      httpMiracleMock.open(url).reply(data.readAsBytesSync(),
          headers: {Headers.contentTypeHeader: 'image/png'});
      await Utils.pumpWidgetWithImages(
        tester,
        Column(
          children: [
            // ignore: avoid_unnecessary_containers
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
        matchesGoldenFile('snapshots/net_work_image_2.png'),
      );
    });
  });

  group('Using httpClient', () {
    final httpClient = HttpClient();
    test('test get', () async {
      var url = 'https://example.com/create';
      var data = "resultGet";
      var uri = Uri.parse(url);
      httpMiracleMock.open(url).reply(data);
      final request = await httpClient.get(uri.host, uri.port, uri.path);
      final response = await request.close();
      var responseData = await response.transform(utf8.decoder).join();
      expect(responseData, data);
    });
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
    test('test post', () async {
      var url = 'https://example.com/create1';
      var data = "resultPost";
      var requestData = {'name': 'doodle', 'color': 'blue'};
      var uri = Uri.parse(url);
      httpMiracleMock.open(url, data: requestData).reply(data);
      final request = await httpClient.post(uri.host, uri.port, uri.path);
      request.addStream(Stream.value((utf8.encode(jsonEncode(requestData)))));
      final response = await request.close();
      var responseData = await response.transform(utf8.decoder).join();
      expect(responseData, data);
    });
    test('test postUrl', () async {
      var url = 'https://example.com/create1';
      var data = "resultPostUrl";
      var requestData = {'name': 'doodle', 'color': 'blue'};
      var uri = Uri.parse(url);
      httpMiracleMock.open(url, data: requestData).reply(data);
      final request = await httpClient.postUrl(uri);
      request.addStream(Stream.value((utf8.encode(jsonEncode(requestData)))));
      final response = await request.close();
      var responseData = await response.transform(utf8.decoder).join();
      expect(responseData, data);
    });
    test('test openUrl', () async {
      var url = 'http://example.com/create1';
      var data = "resultOpenUrl";
      var requestData = {'name': 'doodle', 'color': 'blue'};
      httpMiracleMock.open(url, data: requestData).reply(data);
      final request = await httpClient.openUrl('POST', Uri.parse(url));
      request.addStream(Stream.value((utf8.encode(jsonEncode(requestData)))));
      final response = await request.close();
      var responseData = await response.transform(utf8.decoder).join();
      expect(responseData, data);
    });
  });

  group('using dio', () {
    test('test method get', () async {
      var data = {"success": true};
      httpMiracleMock.open('http://example.com/111').reply(data,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      var res = await Dio().get('http://example.com/111');
      expect(res.data, data);
    });
    test('test method post', () async {
      var data = {"success": true};
      httpMiracleMock.open('http://example.com/222').reply(data,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      var res = await Dio().post('http://example.com/222');
      expect(res.data, data);
    });

    test('test method post response data string', () async {
      var data = "Yes";
      var url = 'http://example.com/hgiews}';
      httpMiracleMock.open(url).reply(data);
      var res = await Dio().post(url);
      expect(res.data, data);
    });

    test('test regular ', () async {
      var data = {"success": true};
      var data1 = {"success1": true};
      var url = 'http://example.com/getticket?action=testRegular';
      var url1 = 'http://example.com/getticket?action=testRegular1';
      httpMiracleMock.open(r'.*testRegular$').reply(data);
      httpMiracleMock.open(RegExp(r'.*testRegular1')).reply(data1);
      var res = await Dio().post(url);
      var res1 = await Dio().post(url1);
      expect(res.data, data);
      expect(res1.data, data1);
    });
    test('test Uri for url', () async {
      var data = {"success": true};
      var url = 'http://example.com/go?action=testRegular';
      httpMiracleMock.open(Uri.parse(url)).reply(data);
      var res = await Dio().post(url);
      expect(res.data, data);
    });

    test('test matching failure ', () async {
      var data = {"success": true};
      var url = 'http://example.com/getticket?action=goto404';
      httpMiracleMock.open(r'.*testRegular1').reply(data);
      try {
        await Dio().post(url);
      } on DioError catch (e) {
        expect(e.response!.statusCode, 404);
      }
    });

    test('test GET query', () async {
      var data = {"success": true};
      var data1 = {"success1": false};
      var url = 'http://example.com/224';
      httpMiracleMock.open('$url?test=true').reply(data,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      httpMiracleMock.open(url).reply(data1,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      var res1 = await Dio().get(url);
      var res = await Dio().get(url, queryParameters: {"test": true});
      expect(res.data, data);
      expect(res1.data, data1);
    });

    test('test method', () async {
      var dataPost = {"success": true};
      var dataGet = {"success1": false};
      var url = 'http://example.com/222';
      httpMiracleMock.open(url, method: 'Get').reply(dataGet,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      httpMiracleMock.open(url, method: 'Post').reply(dataPost,
          headers: {HttpHeaders.contentTypeHeader: ContentType.json.value});
      var resGet = await Dio().get(url);
      var resPost = await Dio().post(url);
      expect(resPost.data, dataPost);
      expect(resGet.data, dataGet);
    });

    test('test POST data', () async {
      var data = {"success": true};
      var dataNo = {"success1": false};
      var requestData = {"test": true};
      var requestDataNo = {"test1": true};
      var url = 'http://example.com/321xx';
      httpMiracleMock.open(url, data: requestData).reply(data);
      httpMiracleMock.open(url, data: requestDataNo).reply(dataNo);
      var res = await Dio().post(url, data: {...requestData, "hhh": "冲"});
      var resNo =
          await Dio().post(url, data: {...requestDataNo, "token": "123"});
      //参数传递无法匹配时，报404
      try {
        var resError = await Dio().post(url, data: {"test1": false});
        expect(resError, isNull);
      } on DioError catch (e) {
        expect(e.response!.statusCode, 404);
      }
      expect(res.data, data);
      expect(resNo.data, dataNo);
    });

    test('test POST data stream', () async {
      var requestData =
          File(path.join(Utils.currentPath, 'test', 'assets', 'test.png'));
      var data = {"success": true};
      List<int> bytes = requestData.readAsBytesSync();
      var url = 'http://example.com/dafade';
      httpMiracleMock.open(url, data: bytes).reply(data);
      var res =
          await Dio().post(url, data: Stream<List<int>>.fromIterable([bytes]));
      expect(res.data, data);
    });
    var dataTestUrl = 'http://example.com/xsf32x';
    test('test POST data List<int>', () async {
      var requestData = [123, 345];
      var data = {"success": true};
      httpMiracleMock.open(dataTestUrl, data: requestData).reply(data);
      var res = await Dio().post(dataTestUrl, data: jsonEncode(requestData));
      expect(res.data, data);
    });
    test('test POST data List<String>', () async {
      var requestData = ["AB", "CD"];
      var data = {"success": true};
      // https://github.com/cfug/dio/issues/172
      httpMiracleMock.open(dataTestUrl, data: requestData).reply(data);
      var res = await Dio().post(dataTestUrl, data: jsonEncode(requestData));
      expect(res.data, data);
    });
    test('test POST data String', () async {
      var requestData = "test";
      var data = {"success": true};
      httpMiracleMock.open(dataTestUrl, data: requestData).reply(data);
      var res = await Dio().post(dataTestUrl, data: requestData);
      expect(res.data, data);
    });

    test('test response string conver to map automatic', () async {
      var data = '{"test":"true"}';
      httpMiracleMock.open(dataTestUrl).reply(data);
      var res = await Dio().post(dataTestUrl);
      expect(res.data, json.decode(data));
    });

    test('test urlDataToMap', () async {
      var respectData = {"test": '123', 'params': '321'};
      var data = '123';
      var url = 'http://example.com/dsdfqe23?';
      httpMiracleMock.open(url, data: respectData).reply(data);
      var res = await Dio().post(url,
          data: respectData,
          options: Options(contentType: Headers.formUrlEncodedContentType));
      expect(res.data, data);
    });
    test('test dataTnsform', () async {
      var requestData = '{"test":"false"}';
      var realData = {"test": "true"};
      httpMiracleMock
          .open(dataTestUrl, data: realData, dataTransform: (v) => realData)
          .reply('1');
      var res = await Dio().post(dataTestUrl, data: requestData);
      expect(res.data, '1');
    });
  });

  group('using http', () {
    test('test get', () async {
      var url = 'https://example.com/create';
      var data = """{"success": true}""";
      var uri = Uri.parse(url);
      httpMiracleMock.open(url).reply(data);
      var response = await http.get(uri);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      expect(response.body, data);
    });
    test('test POST', () async {
      var url = 'https://example.com/create1';
      var data = """{"success": true}""";
      var uri = Uri.parse(url);
      httpMiracleMock.open(url, data: 'name=doodle&color=blue').reply(data);
      var response =
          await http.post(uri, body: {'name': 'doodle', 'color': 'blue'});
      expect(response.body, data);
    });
  });
}
