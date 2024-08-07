library flutter_client_sse;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:http/http.dart' as http;

part 'sse_event_model.dart';

/// A client for subscribing to Server-Sent Events (SSE).
class SSEClient {
  final http.Client _client;

  SSEClient(this._client);

  /// Retry the SSE connection after a delay.
  ///
  /// [method] is the request method (GET or POST).
  /// [url] is the URL of the SSE endpoint.
  /// [header] is a map of request headers.
  /// [body] is an optional request body for POST requests.
  void _retryConnection(
      {required SSERequestType method,
      required String url,
      required Map<String, String> header,
      Map<String, dynamic>? body}) {
    print('---RETRY CONNECTION---');
    Future.delayed(Duration(seconds: 5), () {
      subscribeToSSE(
        method: method,
        url: url,
        header: header,
        body: body,
      );
    });
  }

  /// Subscribe to Server-Sent Events.
  ///
  /// [method] is the request method (GET or POST).
  /// [url] is the URL of the SSE endpoint.
  /// [header] is a map of request headers.
  /// [body] is an optional request body for POST requests.
  ///
  /// Returns a [Stream] of [SSEModel] representing the SSE events.
  Stream<SSEModel> subscribeToSSE(
      {required SSERequestType method,
      required String url,
      required Map<String, String> header,
      Map<String, dynamic>? body}) {
    StreamController<SSEModel> _streamController = StreamController();
    var lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');
    var currentSSEModel = SSEModel(data: '', id: '', event: '');
    print("--SUBSCRIBING TO SSE---");
    try {
      var request = new http.Request(
        method == SSERequestType.GET ? "GET" : "POST",
        Uri.parse(url),
      );

      /// Adding headers to the request
      header.forEach((key, value) {
        request.headers[key] = value;
      });

      /// Adding body to the request if exists
      if (body != null) {
        request.body = jsonEncode(body);
      }

      Future<http.StreamedResponse> response = _client.send(request);

      /// Listening to the response as a stream
      response.asStream().listen((data) {
        /// Applying transforms and listening to it
        data.stream
          ..transform(Utf8Decoder()).transform(LineSplitter()).listen(
            (dataLine) {
              if (dataLine.isEmpty) {
                /// This means that the complete event set has been read.
                /// We then add the event to the stream
                _streamController.add(currentSSEModel);
                currentSSEModel = SSEModel(data: '', id: '', event: '');
                return;
              }

              /// Get the match of each line through the regex
              Match match = lineRegex.firstMatch(dataLine)!;
              var field = match.group(1);
              if (field!.isEmpty) {
                return;
              }
              var value = '';
              if (field == 'data') {
                // If the field is data, we get the data through the substring
                value = dataLine.substring(
                  5,
                );
              } else {
                value = match.group(2) ?? '';
              }
              switch (field) {
                case 'event':
                  currentSSEModel.event = value;
                  break;
                case 'data':
                  currentSSEModel.data =
                      (currentSSEModel.data ?? '') + value + '\n';
                  break;
                case 'id':
                  currentSSEModel.id = value;
                  break;
                case 'retry':
                  break;
                default:
                  print('---ERROR---');
                  print(dataLine);
                  _streamController.close();
                  _retryConnection(
                    method: method,
                    url: url,
                    header: header,
                  );
              }
            },
            onError: (e, s) {
              print('---ERROR---');
              print(e);
              _streamController.close();
              _retryConnection(
                method: method,
                url: url,
                header: header,
                body: body,
              );
            },
            onDone: () {
              print('---STREAM DONE---');
              _streamController.close();
            },
          );
      }, onError: (e, s) {
        print('---ERROR---');
        print(e);
        _streamController.close();
        _retryConnection(
          method: method,
          url: url,
          header: header,
          body: body,
        );
      });
    } catch (e) {
      print('---ERROR---');
      print(e);
      _streamController.close();
      _retryConnection(
        method: method,
        url: url,
        header: header,
        body: body,
      );
    }
    return _streamController.stream;
  }
}
