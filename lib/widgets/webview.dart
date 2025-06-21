import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

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
  late final WebViewController _webViewController;
  String? _webViewUrl;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isWebViewReady = false;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _initializePremblyWidget();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress if needed
          },
          onPageStarted: (String url) {
            // Page started loading
          },
          onPageFinished: (String url) {
            _onPageFinished();
          },
          onWebResourceError: (WebResourceError error) {
            widget.onError({
              "status": "webview_error",
              "message": "WebView error: ${error.description}",
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterKYC',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      );
  }

  void _handleJavaScriptMessage(String message) {
    try {
      Map response = json.decode(message);
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
            print("Received unknown event from WebView: ${response['event']}");
            break;
        }
      }
    } catch (e) {
      print("Error decoding JSON from WebView: $e");
      print("Raw data from WebView: $message");
      widget.onError({
        "status": "error",
        "message": "Failed to process message from WebView: $e",
      });
    }
  }

  Future<void> _onPageFinished() async {
    // Inject JavaScript to handle messages from the web page
    await _webViewController.runJavaScript('''
      window.addEventListener("message", (event) => {
        FlutterKYC.postMessage(JSON.stringify(event.data));
      }, false);
      
      // Test camera access capability
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        navigator.mediaDevices.getUserMedia({ video: true, audio: true })
          .then(function(stream) {
            console.log('Camera and microphone access granted to web content!');
            stream.getTracks().forEach(track => track.stop());
          })
          .catch(function(err) {
            console.error('Error accessing camera/microphone: ' + err.name + ': ' + err.message);
          });
      } else {
        console.warn('getUserMedia not supported in this browser');
      }
    ''');

    setState(() {
      _isWebViewReady = true;
    });
  }

  Future<void> _initializePremblyWidget() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String apiUrl =
        'https://api.prembly.com/identitypass/internal/checker/sdk/widget/initialize';

    final Map<String, dynamic> requestBody = {
      "first_name": widget.firstName ?? "",
      "public_key": widget.merchantKey,
      "last_name": widget.lastName ?? "",
      "email": widget.email,
      "user_ref": widget.userRef ?? "",
      "config_id": widget.config,
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'accept': '*/*',
          'accept-language': 'en-GB,en-US;q=0.9,en;q=0.8',
          'content-type': 'application/json'
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == true &&
            responseData.containsKey('widget_id')) {
          final String widgetId = responseData['widget_id'];
          setState(() {
            _webViewUrl = "https://dev.d1gc80n5odr0sp.amplifyapp.com/$widgetId";
            _isLoading = false;
          });
          // Load the URL in WebView
          _webViewController.loadRequest(Uri.parse(_webViewUrl!));
        } else {
          setState(() {
            _errorMessage =
                responseData['detail'] ?? 'Failed to get widget ID from API.';
            _isLoading = false;
          });
          widget.onError({"status": "api_error", "message": _errorMessage});
        }
      } else {
        setState(() {
          _errorMessage =
          'API call failed with status: ${response.statusCode}. Response: ${response.body}';
          _isLoading = false;
        });
        widget.onError({"status": "api_error", "message": _errorMessage});
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error or data parsing error: $e';
        _isLoading = false;
      });
      widget.onError({"status": "network_error", "message": _errorMessage});
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: _isLoading
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Initializing secure session..."),
              ],
            ),
          )
              : _errorMessage != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 50),
                  const SizedBox(height: 16),
                  Text(
                    "Error: $_errorMessage",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _initializePremblyWidget,
                    child: const Text("Retry"),
                  ),
                  TextButton(
                    onPressed: () => widget
                        .onCancel({"status": "error_display_closed"}),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ),
          )
              : WebViewWidget(controller: _webViewController),
        ),
      ),
    );
  }
}