import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Callback signature — receives a human-readable error message.
typedef ErrorCallback = void Function(String message);

/// Singleton that centralises error handling across the app.
/// Attach an [onError] callback in your root widget to surface errors in the UI
/// (e.g. show a SnackBar). Errors are always printed in debug mode.
///
/// Set [onSessionExpired] once at startup (e.g. in main.dart) to handle 401s
/// globally — clear tokens and navigate to the login screen.
class AppErrorHandler {
  AppErrorHandler._();

  static final AppErrorHandler instance = AppErrorHandler._();

  /// Optional UI-layer callback. Set once in the root widget build/initState.
  ErrorCallback? onError;

  /// Called when any request returns HTTP 401. Use this to clear the session
  /// and redirect to the login screen via a global NavigatorKey.
  VoidCallback? onSessionExpired;

  /// Parse, log, and optionally surface [error] to the UI.
  /// Returns the human-readable message so callers can use it directly.
  String? handle(Object error, {StackTrace? stackTrace, String? context}) {
    final message = _toMessage(error);
    if (kDebugMode) {
      debugPrint('[AppErrorHandler]${context != null ? ' [$context]' : ''} $message');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    onError?.call(message);
    return message;
  }

  /// Returns a clean, user-facing message for any error type.
  String _toMessage(Object error) {
    if (error is DioException) return _parseDio(error);
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _parseDio(DioException e) {
    // Prefer the backend's own message when available
    final data = e.response?.data;
    if (data is Map) {
      final errorBlock = data['error'];
      if (errorBlock is Map) {
        final msg = errorBlock['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 401) {
          onSessionExpired?.call();
          return 'Your session has expired. Please log in again.';
        }
        if (status == 403) return 'You don\'t have permission to do that.';
        if (status == 404) return 'Resource not found.';
        if (status >= 500) return 'Server error. Please try again later.';
        return 'Unexpected error ($status).';
      default:
        return e.message ?? 'Something went wrong.';
    }
  }
}
