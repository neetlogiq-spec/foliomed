import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/oauth_error.dart';

void main() {
  test('the real failed-exchange URL yields a friendly message', () {
    final uri = Uri.parse('https://www.foliomed.app/app/?error=server_error'
        '&error_code=unexpected_failure&error_description=Unable+to+exchange'
        '+external+code%3A+4%2F0A#/login');
    expect(oauthErrorMessage(uri), contains("couldn't be completed"));
  });

  test('cancel in the fragment is recognised', () {
    final uri = Uri.parse('https://www.foliomed.app/app/#error=access_denied');
    expect(oauthErrorMessage(uri), 'Google sign-in was cancelled.');
  });

  test('no error means no message', () {
    expect(oauthErrorMessage(Uri.parse('https://www.foliomed.app/app/#/login')),
        isNull);
  });
}
