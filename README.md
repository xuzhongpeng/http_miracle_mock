[简体中文](README_ZH.md) | English


[![Pub](https://img.shields.io/pub/v/http_miracle_mock.svg)](https://pub.dev/packages/http_miracle_mock)
[![LICENSE](https://img.shields.io/badge/License-MIT-red.svg)](https://pub.dev/packages/http_miracle_mock#License "Project's LICENSE section")

# http_miracle_mock

Designed for Flutter unit testing, this library allows for easy mocking/intercepting of network requests and images within business logic.

Intercepting network requests in unit tests of Flutter projects is a common scenario. Existing frameworks include:

- [mockito](https://pub.dev/packages/mockito): Not concise enough, requiring a large amount of code.
- [http_mock_adapter](https://pub.dev/packages/http_mock_adapter): Only supports the Dio library. 
- [network_image_mock](https://pub.dev/packages/network_image_mock): Only supports image.

The purpose of this library is to solve the following problems:

1. Easy to use.
2. Compatible with mainstream networking frameworks, such as dio and http.
3. Deals only with network-related issues, such as common network requests and image resources.

## Getting Started

### Adding Dependency

```yaml
dev_dependencies:
  http_miracle_mock: any
```

### Simple Usage
Mocking a GET request:

```dart
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
}
```

Mocking a image:

```dart
testWidgets('test image using url png', (WidgetTester tester) async {
  var data = File(path.join(Utils.currentPath, 'test', 'assets', 'test.png'));
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
```

First, initialize the `HttpMiracleMock`, then use `httpMiracleMock.open` to provide the information needed to intercept the network request, such as request URL and parameters, and then use `reply` to enter the result of the request.

For more usage examples, refer to [here](/test/http_miracle_mock_test.dart).

## API

For simplicity, the library provides only the HttpMiracleMock object, which offers an open interface.

### open

The open method is primarily used to define the information for the request to be intercepted, with the following parameters:

- url: Required, the request URL to intercept, can be passed in as a String, RegExp, or Uri.
- method: Optional, the request method to intercept (GET/POST).
- data: Optional, the request parameters.
- dataTransform: Optional, for request parameter transformation, in case some requests cannot parse the parameters due to compatibility issues, this callback can be used for custom conversion. 

The `method`, `data`,and `dataTransform` are optional parameters. In some cases, such as when the URL uses a regular expression, it may match multiple different requests in the project; these additional parameters can be used to differentiate and make the match more accurate. 

This method returns a ResponseData.

### reply

- body: Required, the data content to return.
- statusCode: Optional, the status code to return.
- headers: The header information to return.