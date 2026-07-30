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

  /// Called when the session is genuinely over — the refresh token was missing
  /// or rejected. Use this to clear the session and redirect to the login screen
  /// via a global NavigatorKey.
  ///
  /// Fired by `AuthInterceptor`, **not** here: a 401 on its own is routine and
  /// usually recoverable by refreshing, so this class only turns it into a
  /// message. Firing on every 401 logged out users who had a valid refresh
  /// token.
  VoidCallback? onSessionExpired;

  /// Reason phrases a framework emits when no handler supplied a message —
  /// `{"message": "Not Found"}` says nothing the 404 didn't. Only a body that
  /// echoes its *own* status phrase is dropped; every other server string is
  /// shown to the user verbatim.
  static const Map<int, String> _statusPhrases = {
    400: 'badrequest',
    401: 'unauthorized',
    403: 'forbidden',
    404: 'notfound',
    405: 'methodnotallowed',
    409: 'conflict',
    422: 'unprocessableentity',
    429: 'toomanyrequests',
    500: 'internalservererror',
    501: 'notimplemented',
    502: 'badgateway',
    503: 'serviceunavailable',
    504: 'gatewaytimeout',
  };

  /// Parse, log, and optionally surface [error] to the UI.
  /// Returns the human-readable message so callers can use it directly.
  String? handle(Object error, {StackTrace? stackTrace, String? context}) {
    final message = _toMessage(error);
    if (kDebugMode) {
      final where = <String>[
        if (context != null && context.isNotEmpty) context,
        ?_origin(error),
      ].join(' · ');
      debugPrint(
        '[AppErrorHandler]${where.isEmpty ? '' : ' [$where]'} $message',
      );
      // The raw body, so a message we failed to extract is still visible.
      if (error is DioException && error.response?.data != null) {
        debugPrint('[AppErrorHandler] body: ${error.response!.data}');
      }
      final budget = _timeoutBudget(error);
      if (budget != null) debugPrint('[AppErrorHandler] $budget');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
    onError?.call(message);
    return message;
  }

  /// `GET /patient/me/details → 404` — tells you which call failed, which a
  /// bare "Not Found" never does. With no response, the DioException type stands
  /// in for the status, so a timeout says *which* timeout.
  String? _origin(Object error) {
    if (error is! DioException) return null;
    final req = error.requestOptions;
    final status = error.response?.statusCode;
    return '${req.method} ${req.path} → ${status ?? error.type.name}';
  }

  /// Timeouts are routinely misread as "the server is slow" when the real cause
  /// is a stale client config, so print the budget that was actually in force.
  /// [RequestOptions] carries the effective values for that request.
  String? _timeoutBudget(Object error) {
    if (error is! DioException) return null;
    const timeoutTypes = {
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    };
    if (!timeoutTypes.contains(error.type)) return null;

    final o = error.requestOptions;
    String s(Duration? d) => d == null ? 'unset' : '${d.inSeconds}s';
    return 'timeouts in effect — connect ${s(o.connectTimeout)}, '
        'send ${s(o.sendTimeout)}, receive ${s(o.receiveTimeout)}';
  }

  /// Returns a clean, user-facing message for any error type.
  String _toMessage(Object error) {
    if (error is DioException) return _parseDio(error);
    return error.toString().replaceFirst('Exception: ', '');
  }

  String _parseDio(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final backend = _backendMessage(e.response?.data, status);

    // A 401 that reaches here has already survived AuthInterceptor's refresh
    // attempt, so on an authenticated request the session really is over — but
    // the redirect is the interceptor's job, not ours. Without a token it's just
    // a failed sign-in, so the backend's own wording is what the user needs.
    if (status == 401) {
      final wasAuthenticated =
          e.requestOptions.headers.containsKey('Authorization');
      if (wasAuthenticated) {
        return 'Your session has expired. Please log in again.';
      }
      return backend ?? 'Incorrect email or password.';
    }

    // Prefer the backend's own message, but only when it says something the
    // status code doesn't already.
    if (backend != null) return backend;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Request timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return "Couldn't establish a secure connection.";
      case DioExceptionType.badResponse:
        return _statusMessage(status);
      case DioExceptionType.unknown:
        return e.error is FormatException
            ? 'The server sent an unexpected response.'
            : e.message ?? 'Something went wrong. Please try again.';
    }
  }

  /// Friendly wording for a status code with no usable body.
  String _statusMessage(int status) {
    if (status == 400) return 'That request was not valid. Please check your details.';
    if (status == 403) return "You don't have permission to do that.";
    if (status == 404) {
      // Almost always a client/server contract mismatch rather than anything the
      // user did — say so plainly instead of the raw "Not Found".
      return "We couldn't find that on the server. Please try again, or contact "
          'support if it keeps happening.';
    }
    if (status == 409) return 'That conflicts with something that already exists.';
    if (status == 422) return "Some of those details couldn't be saved. Please review them.";
    if (status == 429) return 'Too many attempts. Please wait a moment and try again.';
    if (status >= 500) return 'Server error. Please try again later.';
    return status == 0
        ? 'Something went wrong. Please try again.'
        : 'Unexpected error ($status).';
  }

  /// Digs the server's own message out of the response body, whatever shape it
  /// takes:
  ///   {"error": {"code": "...", "message": "..."}}
  ///   {"error": "..."} / {"message": "..."} / {"detail": "..."}
  ///   {"errors": ["...", "..."]} / {"errors": {"email": ["..."]}}
  /// Returns null only when the body is empty or merely echoes [status]'s
  /// reason phrase.
  String? _backendMessage(Object? data, int status) {
    if (data is String) return _clean(data, status);
    if (data is! Map) return null;

    final errorBlock = data['error'] ?? data['errors'];
    if (errorBlock is Map) {
      // Field-level validation errors, as returned for a 422:
      //   error.details: [{ field, message, type }, …]
      // The parent message ("The submitted data is invalid.") says nothing about
      // which field, so prefer these when present.
      final fromDetails = _fieldMessages(errorBlock['details'], status);
      if (fromDetails != null) return fromDetails;

      final nested = _clean(errorBlock['message'], status) ??
          _clean(errorBlock['detail'], status) ??
          _clean(errorBlock['description'], status);
      if (nested != null) return nested;
      // Validation shape: {"email": ["is already taken"]}
      final fromFields = errorBlock.values
          .map((v) => _clean(v, status))
          .whereType<String>()
          .toList();
      if (fromFields.isNotEmpty) return fromFields.join('\n');
    }

    return _clean(data['message'], status) ??
        _clean(data['detail'], status) ??
        _clean(errorBlock, status) ??
        _clean(data['description'], status);
  }

  /// Renders `[{field, message}, …]` as user-facing lines, e.g.
  ///   `Other conditions: 'none' cannot be combined with other values`
  ///
  /// Array indices in a field path (`current_supplements.6`) are dropped — the
  /// position within a list means nothing to the person reading it.
  String? _fieldMessages(Object? details, int status) {
    if (details is! List || details.isEmpty) return null;

    final lines = <String>[];
    for (final entry in details) {
      if (entry is! Map) continue;
      final message = _clean(entry['message'], status);
      if (message == null) continue;

      final field = entry['field'];
      if (field is! String || field.isEmpty) {
        lines.add(message);
        continue;
      }
      final name = field
          .split('.')
          .where((part) => int.tryParse(part) == null)
          .join(' ')
          .replaceAll('_', ' ');
      final label = name.isEmpty
          ? ''
          : '${name[0].toUpperCase()}${name.substring(1)}: ';
      lines.add('$label$message');
    }

    return lines.isEmpty ? null : lines.join('\n');
  }

  /// Normalises a candidate message; returns null when it carries no
  /// information beyond [status]. Lists are flattened, non-strings ignored.
  String? _clean(Object? value, int status) {
    if (value is List) {
      final parts =
          value.map((v) => _clean(v, status)).whereType<String>().toList();
      return parts.isEmpty ? null : parts.join('\n');
    }
    if (value is! String) return null;

    final text = value.trim();
    if (text.isEmpty) return null;
    // Bare HTML error pages ("<!DOCTYPE html>...") are never user-facing.
    if (text.startsWith('<')) return null;

    final normalised = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (normalised == 'null' || normalised == 'error') return null;
    if (normalised == _statusPhrases[status]) return null;

    return text;
  }
}