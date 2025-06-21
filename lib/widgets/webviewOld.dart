import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class IdentityKYCWebView extends StatefulWidget {
  final String merchantKey;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? userRef;
  final String config;
  final Function onCancel;
  final Function onVerified;
  final Function onError;

  IdentityKYCWebView({
    required this.merchantKey,
    required this.email,
    required this.config,
    this.firstName,
    this.lastName,
    this.userRef,
    required this.onCancel,
    required this.onVerified,
    required this.onError,
  });

  @override
  _IdentityKYCWebViewState createState() => _IdentityKYCWebViewState();
}

class _IdentityKYCWebViewState extends State<IdentityKYCWebView> {
  late WebViewController _webViewController;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // // Enable platform-specific features
    // if (Platform.isAndroid) {
    //   WebView.platform = AndroidWebView();
    // }

    _initializeWebViewController();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            _injectJavaScript();
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterInAppWebView',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(
        "https://dev.d1gc80n5odr0sp.amplifyapp.com/39a5c5cc-eaa5-4577-9093-3c2acfa1807f",
      ));
  }

  void _handleJavaScriptMessage(String messageData) {
    try {
      // Handle the message similar to the original code
      if (messageData.isNotEmpty) {
        Map response = json.decode(messageData);
        if (response.containsKey("event")) {
          switch (response["event"]) {
            case "closed":
              widget.onCancel({"status": "closed"});
              break;
            case "error":
              widget.onError({
                "status": "error",
                "message": response['message'],
              });
              break;
            case "verified":
              widget.onVerified({
                "status": "success",
                "data": response,
              });
              break;
            default:
              break;
          }
        }
      } else {
        print("Received empty data from JavaScript handler");
      }
    } catch (e) {
      print("Error decoding JSON from WebView: $e");
      print("Raw data from WebView: $messageData");
      widget.onError({
        "status": "error",
        "message": "Failed to process message from WebView: $e",
      });
    }
  }

  void _injectJavaScript() {
    final String jsCode = '''
      (function() {
        console.log('Injecting JavaScript for KYC WebView');
        
        // Set up message listener for postMessage communication
        window.addEventListener("message", function(event) {
          console.log('WEB CONSOLE: Received message event');
          console.log('WEB CONSOLE: Event data:', event.data);
          
          try {
            // Send the event data to Flutter
            if (typeof event.data === 'object' && event.data !== null) {
              FlutterInAppWebView.postMessage(JSON.stringify(event.data));
            } else if (typeof event.data === 'string') {
              // Try to parse and re-stringify to ensure valid JSON
              var parsedData = JSON.parse(event.data);
              FlutterInAppWebView.postMessage(JSON.stringify(parsedData));
            }
          } catch (e) {
            console.error('WEB CONSOLE: Error processing message:', e);
            FlutterInAppWebView.postMessage(JSON.stringify({
              event: 'error',
              message: 'Error processing message: ' + e.message
            }));
          }
        }, false);

        // Test camera and microphone access
        navigator.mediaDevices.getUserMedia({ video: true, audio: true })
          .then(function(stream) {
            console.log('WEB CONSOLE: Camera and microphone access granted to web content!');
            // Clean up the test stream
            stream.getTracks().forEach(track => track.stop());
          })
          .catch(function(err) {
            console.error('WEB CONSOLE: Error accessing camera/microphone in web content: ' + err.name + ': ' + err.message);
            FlutterInAppWebView.postMessage(JSON.stringify({
              event: 'error',
              message: 'Camera/microphone access denied: ' + err.message
            }));
          });

        // Override console methods to capture logs
        const originalLog = console.log;
        console.log = function(...args) {
          originalLog.apply(console, args);
          // Send log to Flutter for debugging
          try {
            FlutterInAppWebView.postMessage(JSON.stringify({
              event: 'log',
              message: 'WEB CONSOLE: ' + args.join(' ')
            }));
          } catch (e) {
            // Ignore errors when sending logs
          }
        };

        const originalError = console.error;
        console.error = function(...args) {
          originalError.apply(console, args);
          // Send error to Flutter
          try {
            FlutterInAppWebView.postMessage(JSON.stringify({
              event: 'error',
              message: 'WEB CONSOLE ERROR: ' + args.join(' ')
            }));
          } catch (e) {
            // Ignore errors when sending logs
          }
        };

        console.log('WEB CONSOLE: JavaScript injection completed');
      })();
    ''';

    _webViewController.runJavaScript(jsCode).catchError((error) {
      print('Error injecting JavaScript: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => WebViewWidget(
                  controller: _webViewController,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}