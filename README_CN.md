中文 | [英文](README.md)

# http_miracle_mock

用于Flutter单元测试，轻松模拟/拦截业务中的网络请求与网络图片。

Flutter项目的单元测试中拦截业务中的网络请求是一个很常见的场景，当前已有的框架有

- [mockito](https://pub.dev/packages/mockito): 不够简洁，需要大量代码
- [http_mock_adapter](https://pub.dev/packages/http_mock_adapter): 仅支持Dio库

此库的目的为了解决以下问题

1. 简单好用
2. 兼容主流网络请求框架，如dio、http
3. 仅仅处理网络相关问题，如常见的网络请求与图片资源等

## 开始使用

### 引入依赖

```yaml
dev_dependencies:
  http_miracle_mock: any
```

### 简单使用

模拟一个Get请求

```dart
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final HttpMiracleMock httpMiracleMock = HttpMiracleMock();
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

首先，初始化一下`HttpMiracleMock`，然后使用`httpMiracleMock.open`来提供需要拦截的网络请求的信息如请求链接、请求参数等，然后通过`reply`填入该请求的返回结果。

更多使用可以参考[这里](/test/http_miracle_mock_test.dart)

## 接口

为了使用更加简单，该库仅提供`HttpMiracleMock`对象，该对象提供一个`open`接口。

### open

open方法主要用于定义需要拦截请求的信息，有以下参数

- url: 必填，拦截的请求链接，可选传入String，RegExp，Uri类型
- method: 可选，拦截请求方法（GET/POST）
- data: 可选，请求入参
- dataTransform: 可选，用于请求参数转换，如果某些请求因为兼容问题无法解析请求参数，可以先通过此回调进行自定义转换

`method`、`data`、`dataTransform`都是可选参数，某些情况下比如url使用正则时会匹配到项目中多个不同请求，可以用这些更多的参数进行区分，让匹配更加精准。

该方法返回一个`ResponseData`

### reply

- body: 必填，返回的数据内容
- statusCode: 可选，返回的状态的码
- headers: 返回的头部信息