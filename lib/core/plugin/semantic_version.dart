import '../error/app_error.dart';

/// Versi semver minimal yang dipakai manifest plugin.
///
/// Build metadata diabaikan saat perbandingan, sesuai Semantic Versioning
/// 2.0.0. Pre-release dibandingkan dengan aturan standar.
final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.build,
  });

  factory SemanticVersion.parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw _invalid(input, 'Versi tidak boleh kosong.');
    }

    final plusIndex = value.indexOf('+');
    final withoutBuild = plusIndex == -1
        ? value
        : value.substring(0, plusIndex);
    final build = plusIndex == -1 ? null : value.substring(plusIndex + 1);
    if (plusIndex != -1 && !_isValidBuild(build!)) {
      throw _invalid(input, 'Build metadata tidak valid.');
    }

    final dashIndex = withoutBuild.indexOf('-');
    final core = dashIndex == -1
        ? withoutBuild
        : withoutBuild.substring(0, dashIndex);
    final prerelease = dashIndex == -1
        ? null
        : withoutBuild.substring(dashIndex + 1);

    final parts = core.split('.');
    if (parts.length != 3) {
      throw _invalid(input, 'Versi harus berformat major.minor.patch.');
    }
    final numbers = <int>[];
    for (final part in parts) {
      if (!_isNumericIdentifier(part)) {
        throw _invalid(input, 'Komponen versi tidak valid: $part');
      }
      numbers.add(int.parse(part));
    }

    if (prerelease != null && !_isValidPrerelease(prerelease)) {
      throw _invalid(input, 'Pre-release tidak valid.');
    }

    return SemanticVersion(
      major: numbers[0],
      minor: numbers[1],
      patch: numbers[2],
      prerelease: prerelease,
      build: build,
    );
  }

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;
  final String? build;

  bool isAtLeast(SemanticVersion other) => compareTo(other) >= 0;

  @override
  int compareTo(SemanticVersion other) {
    final core = major.compareTo(other.major) != 0
        ? major.compareTo(other.major)
        : minor.compareTo(other.minor) != 0
        ? minor.compareTo(other.minor)
        : patch.compareTo(other.patch);
    if (core != 0) {
      return core;
    }

    if (prerelease == null && other.prerelease == null) {
      return 0;
    }
    if (prerelease == null) {
      return 1;
    }
    if (other.prerelease == null) {
      return -1;
    }

    final left = prerelease!.split('.');
    final right = other.prerelease!.split('.');
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final a = left[index];
      final b = right[index];
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      if (aNumber != null && bNumber != null) {
        final result = aNumber.compareTo(bNumber);
        if (result != 0) {
          return result;
        }
      } else if (aNumber != null) {
        return -1;
      } else if (bNumber != null) {
        return 1;
      } else {
        final result = a.compareTo(b);
        if (result != 0) {
          return result;
        }
      }
    }
    return left.length.compareTo(right.length);
  }

  @override
  String toString() {
    final buffer = StringBuffer('$major.$minor.$patch');
    if (prerelease != null) {
      buffer.write('-$prerelease');
    }
    if (build != null) {
      buffer.write('+$build');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    return other is SemanticVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        prerelease == other.prerelease;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);
}

bool _isNumericIdentifier(String value) {
  if (value.isEmpty) {
    return false;
  }
  if (value.length > 1 && value.startsWith('0')) {
    return false;
  }
  return int.tryParse(value) != null;
}

bool _isValidPrerelease(String value) {
  if (value.isEmpty) {
    return false;
  }
  for (final identifier in value.split('.')) {
    if (!_isValidIdentifier(identifier)) {
      return false;
    }
    if (int.tryParse(identifier) != null &&
        identifier.length > 1 &&
        identifier.startsWith('0')) {
      return false;
    }
  }
  return true;
}

bool _isValidBuild(String value) {
  if (value.isEmpty) {
    return false;
  }
  return value.split('.').every(_isValidIdentifier);
}

bool _isValidIdentifier(String value) {
  return value.isNotEmpty && RegExp(r'^[0-9A-Za-z-]+$').hasMatch(value);
}

AppError _invalid(String input, String message) {
  return AppError(
    category: ErrorCategory.validation,
    code: 'plugin.version_invalid',
    message: '$message (versi: $input)',
    details: <String, Object?>{'version': input},
  );
}
