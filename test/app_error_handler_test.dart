import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_monitor_demo/core/session/app_error_handler.dart';

/// Builds a DioException carrying [data] with [status], as if returned by
/// [path]. [authed] mirrors the Authorization header the Dio interceptor adds
/// once the user is signed in.
DioException _err(
  int status,
  Object? data, {
  String path = '/onboarding',
  bool authed = false,
}) {
  final options = RequestOptions(
    path: path,
    method: 'GET',
    headers: authed ? {'Authorization': 'Bearer abc'} : <String, dynamic>{},
  );
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  final handler = AppErrorHandler.instance;

  tearDown(() {
    handler.onError = null;
    handler.onSessionExpired = null;
  });

  group('backend message wins', () {
    test('nested error.message is surfaced verbatim', () {
      expect(
        handler.handle(_err(404, {
          'error': {'code': 'not_found', 'message': 'No patient record yet.'}
        })),
        'No patient record yet.',
      );
    });

    test('top-level message is surfaced verbatim', () {
      expect(
        handler.handle(_err(400, {'message': 'Referral code already used.'})),
        'Referral code already used.',
      );
    });

    test('string error field is surfaced', () {
      expect(
        handler.handle(_err(409, {'error': 'That email is already registered.'})),
        'That email is already registered.',
      );
    });

    test('detail field is surfaced', () {
      expect(
        handler.handle(_err(422, {'detail': 'date_of_birth must be a date.'})),
        'date_of_birth must be a date.',
      );
    });

    test('422 error.details name the offending fields', () {
      // The real 422 from PATCH /patient/me/details. The parent message alone
      // ("The submitted data is invalid.") does not say what to fix.
      final msg = handler.handle(_err(422, {
        'error': {
          'code': 'validation_error',
          'message': 'The submitted data is invalid.',
          'details': [
            {
              'field': 'other_conditions',
              'message': "Value error, 'none' cannot be combined with other values",
              'type': 'value_error',
            },
            {
              'field': 'current_supplements.6',
              'message': "Input should be 'vitamin_d' or 'other'",
              'type': 'enum',
            },
          ],
        }
      }))!;

      expect(msg, contains('Other conditions:'));
      expect(msg, contains("'none' cannot be combined"));
      // The array index is noise to the reader.
      expect(msg, contains('Current supplements:'));
      expect(msg, isNot(contains('.6')));
      expect(msg, isNot(contains('The submitted data is invalid')));
    });

    test('a detail with no field still surfaces its message', () {
      expect(
        handler.handle(_err(422, {
          'error': {
            'message': 'Invalid',
            'details': [
              {'message': 'Date of birth must be in the past'},
            ],
          }
        })),
        'Date of birth must be in the past',
      );
    });

    test('empty details fall back to the parent message', () {
      expect(
        handler.handle(_err(422, {
          'error': {'message': 'Could not save your details.', 'details': []}
        })),
        'Could not save your details.',
      );
    });

    test('field-keyed validation errors are joined', () {
      final msg = handler.handle(_err(422, {
        'errors': {
          'email': ['is already taken'],
          'password': ['is too short'],
        }
      }));
      expect(msg, contains('is already taken'));
      expect(msg, contains('is too short'));
    });

    test('plain-string body is surfaced', () {
      expect(
        handler.handle(_err(400, 'Referral code expired.')),
        'Referral code expired.',
      );
    });
  });

  group('status-phrase echoes fall back to our wording', () {
    test('404 + "Not Found" does not reach the user', () {
      final msg = handler.handle(_err(404, {'message': 'Not Found'}))!;
      expect(msg, isNot('Not Found'));
      expect(msg, contains("couldn't find"));
    });

    test('500 + "Internal Server Error" falls back', () {
      expect(
        handler.handle(_err(500, {'message': 'Internal Server Error'})),
        'Server error. Please try again later.',
      );
    });

    test('a phrase that does not match its own status is kept', () {
      // "Not Found" under a 400 is a real statement, not framework boilerplate.
      expect(handler.handle(_err(400, {'message': 'Not Found'})), 'Not Found');
    });

    test('empty body falls back to status wording', () {
      expect(
        handler.handle(_err(403, null)),
        "You don't have permission to do that.",
      );
    });

    test('HTML error page never reaches the user', () {
      final msg = handler.handle(_err(502, '<!DOCTYPE html><h1>502</h1>'))!;
      expect(msg, isNot(contains('<')));
    });
  });

  group('401 handling', () {
    test('authenticated 401 reads as session expiry', () {
      final msg = handler.handle(
        _err(401, {'message': 'Token expired'},
            path: '/patient/me/details', authed: true),
      );
      expect(msg, 'Your session has expired. Please log in again.');
    });

    test('does not itself end the session — AuthInterceptor owns that', () {
      // A 401 reaching the handler has already failed AuthInterceptor's refresh.
      // If this class also fired the callback, a recoverable 401 would log the
      // user out before a refresh could be attempted.
      var expired = false;
      handler.onSessionExpired = () => expired = true;
      handler.handle(
        _err(401, {'message': 'Token expired'},
            path: '/patient/me/details', authed: true),
      );
      expect(expired, isFalse);
    });

    test('unauthenticated 401 shows the backend message', () {
      final msg = handler.handle(
        _err(401, {
          'error': {'message': 'Invalid email or password.'}
        }, path: '/auth/login'),
      );
      expect(msg, 'Invalid email or password.');
    });
  });

  group('transport errors', () {
    test('connection error', () {
      final options = RequestOptions(path: '/onboarding');
      expect(
        handler.handle(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        )),
        'No internet connection.',
      );
    });

    test('non-Dio exception strips the Exception: prefix', () {
      expect(handler.handle(Exception('Nothing to sync')), 'Nothing to sync');
    });
  });

  test('onError receives the same message that is returned', () {
    String? seen;
    handler.onError = (m) => seen = m;
    final returned = handler.handle(_err(400, {'message': 'Bad code.'}));
    expect(seen, returned);
  });
}