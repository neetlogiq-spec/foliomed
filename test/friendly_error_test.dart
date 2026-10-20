import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/friendly_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;

void main() {
  test('database permission and constraint errors read plainly', () {
    expect(friendlyError(const PostgrestException(message: 'x', code: '42501')), contains('member of this ward'));
    expect(friendlyError(const PostgrestException(message: 'dup', code: '23505')), 'That already exists.');
    expect(friendlyError(const PostgrestException(message: 'gone', code: 'P0002')), contains('no longer available'));
  });

  test('our own function messages pass through, capitalised', () {
    expect(friendlyError(const PostgrestException(message: 'set the date and time of birth first', code: '22023')),
        'Set the date and time of birth first.');
  });

  test('admin guard messages', () {
    expect(friendlyError(const PostgrestException(message: 'cannot remove the last admin', code: 'P0001')),
        contains('at least one admin'));
  });

  test('offline and sign-in problems', () {
    expect(friendlyError(const SocketException('Failed host lookup')), contains('can’t reach the server'));
    expect(friendlyError(const AuthException('Email rate limit exceeded', statusCode: '429')), contains('Too many attempts'));
    expect(friendlyError(const AuthException('something odd')), contains('Signing in'));
  });

  test('anything else gets a calm generic line, short strings pass through', () {
    expect(friendlyError(Exception('boom')), 'That didn’t work. Please try again.');
    expect(friendlyError('This plan is no longer available.'), 'This plan is no longer available.');
  });
}
