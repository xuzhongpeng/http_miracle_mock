import 'dart:convert';
import 'dart:io';

import 'dart:async' show Future, Stream, Completer;
import 'dart:typed_data';
import 'package:mockito/mockito.dart'
    show Mock, any, anyNamed, captureAny, when;
import 'package:mockito/annotations.dart';
@GenerateMocks([HttpClient, HttpClientRequest, HttpClientResponse])
import 'http_miracle_mock.mocks.dart';

/// 网络请求mock
/// 支持dio，Image.network等
///
class HttpMiracleMock {
  late _HttpOverrides _overrides;
  HttpMiracleMock() {
    _overrides = _HttpOverrides(this);
    _checkGlobal();
  }

  void _checkGlobal() {
    if (HttpOverrides.current != _overrides) {
      HttpOverrides.global = _overrides;
    }
  }

  final List<ResponseData> _mockData = [];

  /// 传入url，支持String，RegExp，Uri类型
  ///
  /// - url 请求地址，可以直接使用正则
  /// - method 请求方法，不区分大小写
  /// - data 请求参数，支持String
  /// - dataTransform 某些情况下可以将请求参数转换再使用
  ResponseData open(dynamic url,
      {String? method, dynamic data, DataTransform? dataTransform}) {
    assert(url is String || url is RegExp || url is Uri);
    _checkGlobal();
    var respose = ResponseData._(url, method, data, dataTransform);
    _mockData.add(respose);
    return respose;
  }

  /// 找寻对应的ResponseData
  /// TODO 支持contentType
  ResponseData? _find(
    Uri url,
    String? method,
    String? data,
    HttpHeaders? headers,
  ) {
    Map<Compatibility, List<ResponseData>> allMatches = {};
    for (var value in _mockData.reversed) {
      Compatibility matchData = value._matcher(url, method, data, headers);
      if (matchData == Compatibility.perfect) {
        return value;
      } else if (matchData != Compatibility.no) {
        (allMatches[matchData] ??= []).add(value);
      }
    }
    for (var compatibility in [
      Compatibility.fine,
      Compatibility.good,
      Compatibility.ok
    ]) {
      if (allMatches[compatibility] != null &&
          allMatches[compatibility]!.isNotEmpty) {
        return allMatches[compatibility]!.first;
      }
    }
    return null;
  }
}

enum Compatibility {
  perfect, // 匹配度高 url、method、data全匹配
  fine, // url、method、data 有两个匹配
  good, // 中 只有url匹配
  ok, // 低  只有url正则匹配成功
  no, // 未匹配成功
}

typedef DataTransform = dynamic Function(dynamic data);

class ResponseData {
  // 以下是request数据
  final dynamic _url;
  final String? _method;
  final dynamic _data;
  final DataTransform? _dataTransform;

  // 以下是response数据
  int? _statusCode;
  dynamic _body;
  final MockHttpHeaders _headers = MockHttpHeaders();
  MockHttpHeaders get headers => _headers;
  // set headers(MockHttpHeaders headers) => _headers = headers;

  ResponseData._(this._url, this._method, this._data, this._dataTransform);

  /// 返回数据
  ///
  /// - body: 设置返回的实体
  /// - statusCode: 设置返回的状态码
  /// - headers: 设置返回的响应头
  void reply(dynamic body,
      {int statusCode = 200, Map<String, String>? headers}) {
    _statusCode = statusCode;
    _body = body;
    headers?.forEach((k, v) => _headers.set(k, v));
  }

  Compatibility _matcher(
      Uri requestUrl, String? method, dynamic data, HttpHeaders? headers) {
    Compatibility urlMatcher = _matchUrl(requestUrl);
    Compatibility methodMatcher = _matchMethod(method);
    Compatibility dataMatcher = _matchData(data, headers);
    if ([urlMatcher, methodMatcher, dataMatcher].contains(Compatibility.no)) {
      return Compatibility.no;
    } else if (urlMatcher == Compatibility.good &&
        methodMatcher == Compatibility.good &&
        dataMatcher == Compatibility.good) {
      return Compatibility.perfect;
    } else if (urlMatcher == Compatibility.good &&
        (methodMatcher == Compatibility.good ||
            dataMatcher == Compatibility.good)) {
      return Compatibility.fine;
    } else if (urlMatcher == Compatibility.good) {
      return Compatibility.good;
    } else {
      return Compatibility.ok;
    }
  }

  /// 匹配url
  Compatibility _matchUrl(Uri requestUri) {
    if (_url is RegExp) {
      return (_url as RegExp).hasMatch(requestUri.toString())
          ? Compatibility.ok
          : Compatibility.no;
    } else if (_url is String || _url is Uri) {
      Uri uri = _url is Uri ? _url : Uri.parse(_url);
      if (uri == requestUri) return Compatibility.good;
      // 兼容httpClient.post(host, port, path)情况
      if (uri.host == requestUri.host &&
          uri.port == requestUri.port &&
          uri.path == requestUri.path) {
        return Compatibility.ok;
      }
      // 可能是字符串正则
      if (_url is String) {
        try {
          RegExp regExp = RegExp(_url);
          if (regExp.hasMatch(requestUri.toString())) {
            return Compatibility.ok;
          }
        } catch (e) {
          return Compatibility.no;
        }
      }
    }
    return Compatibility.no;
  }

  Compatibility _matchMethod(String? method) {
    return _method == null
        ? Compatibility.ok
        : (_method!.toUpperCase() == method!.toUpperCase()
            ? Compatibility.good
            : Compatibility.no);
  }

  Compatibility _matchData(dynamic data, HttpHeaders? headers) {
    if (_data == null) return Compatibility.ok;
    dynamic actualData = _data;
    dynamic requestData = data;
    if (_data is List<int>) {
      // 二进制解析
      actualData = utf8.decode(_data, allowMalformed: true);
      requestData = _dataTransform?.call(requestData) ?? requestData;
      if (_matches(actualData, requestData)) {
        return Compatibility.good;
      } else {
        actualData = _data;
      }
    }
    // 支持map
    if (_data is Map || _data is List) {
      try {
        Map? temp;
        if (headers?.contentType?.value ==
            'application/x-www-form-urlencoded') {
          temp = _urlTryToMap(data);
        }
        requestData = temp ?? jsonDecode(data);
      } catch (e) {
        // 类型不一样 直接返回false了
        return Compatibility.no;
      }
    }
    requestData = _dataTransform?.call(requestData) ?? requestData;
    return _matches(actualData, requestData)
        ? Compatibility.good
        : Compatibility.no;
  }

  /// 比较类
  bool _matches(dynamic actual, dynamic expected) {
    if (actual == null && expected == null) {
      return true;
    }

    if (actual is Map && expected is Map) {
      for (final key in actual.keys.toList()) {
        if (!expected.containsKey(key)) {
          return false;
        } else if (expected[key] != actual[key]) {
          if (expected[key] is Map && actual[key] is Map) {
            if (!_matches(actual[key], expected[key])) {
              return false;
            }
          } else if (expected[key].toString() != actual[key].toString()) {
            return false;
          }
        }
      }
    } else if (actual is List && expected is List) {
      for (var index in Iterable.generate(actual.length)) {
        if (!_matches(actual[index], expected[index])) {
          return false;
        }
      }
    } else if (actual != expected) {
      return false;
    }

    return true;
  }

  Map? _urlTryToMap(String urlData) {
    // 问题：当传入的参数key都为null时，将不会有=；当传入参数只有一个时，将不会有&
    if (urlData.contains('=') && urlData.contains('&')) {
      try {
        var uri = Uri(query: urlData);
        return uri.queryParameters;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class _HttpOverrides extends HttpOverrides {
  _HttpOverrides(this._httpMock);
  final HttpMiracleMock _httpMock;
  @override
  HttpClient createHttpClient(SecurityContext? c) {
    return _createMockImageHttpClient(c);
  }

  MockHttpClient _createMockImageHttpClient(SecurityContext? _) {
    final client = MockHttpClient();
    Future<HttpClientRequest> setClient(Invocation invocation) async {
      final request = _MockHttpClientRequest();
      when(request.close()).thenAnswer((_) async {
        final response = _MockHttpClientResponse();
        // 处理request
        Uri? requestedUrl; // 请求url
        String? method; // 请求method
        invocation.positionalArguments.forEach((element) {
          if (element is String) {
            method = element;
          } else if (element is Uri) {
            requestedUrl = element;
          }
        });

        var data = await request._transformResponse();

        ResponseData? _responseData =
            _httpMock._find(requestedUrl!, method, data, request.headers);

        when(response.reasonPhrase).thenAnswer((_) => '');
        if (_responseData == null) {
          // 未找到对应url时 报404
          when(response.statusCode).thenReturn(HttpStatus.notFound);
          when(response.headers).thenReturn(MockHttpHeaders());
          when(response.contentLength).thenAnswer((_) => 0);
          when(
            response.listen(
              any,
              cancelOnError: anyNamed('cancelOnError'),
              onDone: anyNamed('onDone'),
              onError: anyNamed('onError'),
            ),
          ).thenAnswer((invocation) {
            final onData =
                invocation.positionalArguments[0] as void Function(List<int>);

            final onDone =
                invocation.namedArguments[#onDone] as void Function();

            final onError = invocation.namedArguments[
                #onError]; //as void Function(Object, StackTrace);

            final cancelOnError =
                invocation.namedArguments[#cancelOnError] as bool?;

            return Stream<List<int>>.fromIterable([]).listen(onData,
                onDone: onDone, onError: onError, cancelOnError: cancelOnError);
          });
        } else {
          // 找到对应url
          when(response.contentLength)
              .thenAnswer((_) => _responseData._body.length);

          when(response.statusCode)
              .thenReturn(_responseData._statusCode ?? 200);
          // 返回数据
          List<int> responseBody;
          var body = _responseData._body;
          if (body == null) {
            responseBody = const Utf8Encoder().convert('');
          } else if (body is String) {
            if (_responseData.headers.isEmpty) {
              try {
                if (body.contains('{')) {
                  json.decode(body);
                  _responseData.headers.set(
                      HttpHeaders.contentTypeHeader, ContentType.json.value);
                }
                // ignore: empty_catches
              } catch (e) {}
            }
            responseBody = const Utf8Encoder().convert(body);
          }
          // 转换参数
          else if (body is Map) {
            responseBody = const Utf8Encoder().convert(json.encode(body));
            if (_responseData.headers.isEmpty) {
              _responseData.headers
                  .set(HttpHeaders.contentTypeHeader, ContentType.json.value);
            }
          } else if (body is List<int>) {
            responseBody = body;
          } else {
            throw 'Unknow Type ${body.runtimeType}. May be you have to implementation it here or pull a issue';
          }

          // catch header
          when(response.headers).thenReturn(_responseData.headers);
          when(
            response.listen(
              any,
              cancelOnError: anyNamed('cancelOnError'),
              onDone: anyNamed('onDone'),
              onError: anyNamed('onError'),
            ),
          ).thenAnswer((invocation) {
            final onData =
                invocation.positionalArguments[0] as void Function(List<int>);

            final onDone =
                invocation.namedArguments[#onDone] as void Function();

            final onError = invocation.namedArguments[
                #onError]; //as void Function(Object, StackTrace);

            final cancelOnError =
                invocation.namedArguments[#cancelOnError] as bool?;

            return Stream<List<int>>.fromIterable([responseBody]).listen(onData,
                onDone: onDone, onError: onError, cancelOnError: cancelOnError);
          });
        }
        return response;
      });

      return request;
    }

    // 拦截openUrl
    when<dynamic>(client.openUrl(captureAny, captureAny)).thenAnswer(setClient);
    // 兼容getUrl 兼容图片
    when<dynamic>(client.getUrl(captureAny)).thenAnswer(setClient);
    // 兼容get
    when<dynamic>(client.get(captureAny, captureAny, captureAny))
        .thenAnswer((invocation) => setClient(Invocation.method(#post, [
              Uri(
                  host: invocation.positionalArguments[0],
                  port: invocation.positionalArguments[1],
                  path: invocation.positionalArguments[2])
            ])));
    // 兼容postUrl
    when<dynamic>(client.postUrl(captureAny)).thenAnswer(setClient);
    // 兼容post
    when<dynamic>(client.post(captureAny, captureAny, captureAny))
        .thenAnswer((invocation) => setClient(Invocation.method(#post, [
              Uri(
                  host: invocation.positionalArguments[0],
                  port: invocation.positionalArguments[1],
                  path: invocation.positionalArguments[2])
            ])));

    return client;
  }
}

/// client
// class MockHttpClient extends Mock implements HttpClient {}

/// request
class _MockHttpClientRequest extends MockHttpClientRequest {
  Stream<List<int>>? stream;
  MockHttpHeaders? _header;
  @override
  HttpHeaders get headers => _header ??= MockHttpHeaders();

  // /// 获取request data参数
  @override
  Future addStream(Stream<List<int>>? stream) async {
    this.stream = stream;
  }

  Future<String?> _transformResponse() async {
    if (stream == null) return null;
    var completer = Completer();
    final chunks = <Uint8List>[];
    var finalSize = 0;
    stream?.listen(
      (chunk) {
        finalSize += chunk.length;
        chunks.add(Uint8List.fromList(chunk));
      },
      onError: (e) {
        completer.completeError(e);
      },
      onDone: () {
        completer.complete();
      },
      cancelOnError: true,
    );
    await completer.future;
    final responseBytes = Uint8List(finalSize);
    var chunkOffset = 0;
    for (var chunk in chunks) {
      responseBytes.setAll(chunkOffset, chunk);
      chunkOffset += chunk.length;
    }
    String responseBody;
    responseBody = utf8.decode(responseBytes, allowMalformed: true);
    return responseBody;
  }
}

/// response
class _MockHttpClientResponse extends MockHttpClientResponse {
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  Stream<S> transform<S>(streamTransformer) {
    return streamTransformer!.bind(this);
  }

  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => []; // 兼容dio
  @override
  bool get persistentConnection => false; // 兼容dio

  /// 兼容http库
  @override
  // ignore: use_function_type_syntax_for_parameters
  Stream<List<int>> handleError(Function? onError, {bool test(error)?}) {
    return this;
  }
}

/// header
class MockHttpHeaders extends Mock implements HttpHeaders {
  final Map<String, List<String>> _headers = {};
  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach((key, value) => action(key, value));
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    name = name.trim().toLowerCase();
    if (value is List) {
      _headers[name] = value.map<String>((e) => e.toString()).toList();
    } else {
      _headers[name] = [value.toString().trim()];
    }
  }

  @override
  ContentType? get contentType =>
      _headers[HttpHeaders.contentTypeHeader] != null &&
              _headers[HttpHeaders.contentTypeHeader]!.isNotEmpty
          ? ContentType.parse(_headers[HttpHeaders.contentTypeHeader]!.first)
          : null;

  bool get isEmpty => _headers.isEmpty;
}
