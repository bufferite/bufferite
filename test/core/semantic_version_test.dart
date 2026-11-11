import 'package:bufferite/core/error/app_error.dart';
import 'package:bufferite/core/plugin/semantic_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SemanticVersion parse', () {
    test('mem-parse versi sederhana dan metadata', () {
      final version = SemanticVersion.parse('1.2.3-rc.1+build.9');
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.prerelease, 'rc.1');
      expect(version.build, 'build.9');
      expect(version.toString(), '1.2.3-rc.1+build.9');
    });

    test('build metadata diabaikan saat perbandingan', () {
      final a = SemanticVersion.parse('1.2.3+one');
      final b = SemanticVersion.parse('1.2.3+two');
      expect(a, b);
      expect(a.compareTo(b), 0);
      expect(a.hashCode, b.hashCode);
    });

    test('pre-release mengikuti urutan semver', () {
      final versions = <SemanticVersion>[
        SemanticVersion.parse('1.0.0-alpha'),
        SemanticVersion.parse('1.0.0-alpha.1'),
        SemanticVersion.parse('1.0.0-alpha.beta'),
        SemanticVersion.parse('1.0.0-beta'),
        SemanticVersion.parse('1.0.0-beta.2'),
        SemanticVersion.parse('1.0.0-beta.11'),
        SemanticVersion.parse('1.0.0-rc.1'),
        SemanticVersion.parse('1.0.0'),
      ];
      for (var index = 1; index < versions.length; index++) {
        expect(
          versions[index - 1].compareTo(versions[index]),
          lessThan(0),
          reason: '${versions[index - 1]} < ${versions[index]}',
        );
      }
    });

    test('isAtLeast membandingkan major, minor, dan patch', () {
      final app = SemanticVersion.parse('1.4.2');
      expect(app.isAtLeast(SemanticVersion.parse('1.4.0')), isTrue);
      expect(app.isAtLeast(SemanticVersion.parse('1.4.2')), isTrue);
      expect(app.isAtLeast(SemanticVersion.parse('1.5.0')), isFalse);
      expect(app.isAtLeast(SemanticVersion.parse('2.0.0')), isFalse);
    });

    test('menolak versi tidak valid dengan error terstruktur', () {
      for (final invalid in <String>[
        '',
        '1',
        '1.0',
        '1.0.0.0',
        '01.0.0',
        '1.02.0',
        '1.0.00',
        '1.0.0-',
        '1.0.0-01',
        '1.0.0-alpha..1',
        '1.0.0+',
        '1.0.0+build..1',
        'v1.0.0',
      ]) {
        expect(
          () => SemanticVersion.parse(invalid),
          throwsA(
            isA<AppError>()
                .having((error) => error.code, 'code', 'plugin.version_invalid')
                .having(
                  (error) => error.category,
                  'category',
                  ErrorCategory.validation,
                ),
          ),
          reason: invalid,
        );
      }
    });
  });
}
