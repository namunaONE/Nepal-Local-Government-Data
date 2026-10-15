// tool/fetch_sources.dart — re-fetch all vendored sources from their upstream
// URLs and verify against data/PROVENANCE.sha256.
//
// This closes the reproducibility gap: a contributor who clones this repo can
// run `dart run tool/fetch_sources.dart` to populate data/_raw/ from the
// original URLs documented in data/SOURCES.md, then run the merge.
//
// Sources and their base URLs (from data/SOURCES.md):
//   abinrimal:        https://raw.githubusercontent.com/abinrimal/nepal-administrative-divisions-json/main
//   local-states-nepal: https://raw.githubusercontent.com/sagautam5/local-states-nepal/master
//   nepali-geo-pro-max: https://raw.githubusercontent.com/l3lackcurtains/nepali-geo-pro-max/main
//   open-admin-data:  https://raw.githubusercontent.com/open-admin-data/nepal-administrative-divisions/main
//   cbs-codes:        CKAN opendatanepal (resource IDs in SOURCES.md)
//   mofaga:           (MoFAGA contact data - URL not publicly documented)
//
// The tool will:
//  1. Parse data/PROVENANCE.sha256 for the expected files + hashes
//  2. Download from each source with retries + timeout
//  3. Verify size + SHA-256 after each download
//  4. Write to data/_raw/ preserving the manifest's directory structure
//  4. Report summary and exit non-zero on any failure
//
// Usage (from the package root):
//   dart run tool/fetch_sources.dart           # full download + verify
//   dart run tool/fetch_sources.dart --verify  # verify only (no download)
//   dart run tool/fetch_sources.dart --list    # list what would be fetched
//
// Exit codes:
//   0  all sources present and matching
//   1  download or verification failed
//   2  manifest invalid or missing
//   3  no network / source URL unavailable

import 'dart:io';
import 'dart:async';

import 'package:crypto/crypto.dart';

final sources = <String, SourceConfig>{
  'abinrimal': SourceConfig(
    name: 'abinrimal',
    baseUrl:
        'https://raw.githubusercontent.com/abinrimal/nepal-administrative-divisions-json/main',
    files: [
      'provinces.json',
      'districts.json',
      'local_levels.json',
      'local_level_types.json',
      'LICENSE',
    ],
  ),
  'local-states-nepal': SourceConfig(
    name: 'local-states-nepal',
    baseUrl:
        'https://raw.githubusercontent.com/sagautam5/local-states-nepal/master',
    files: [
      'dataset_alldataset_en.json',
      'dataset_alldataset_np.json',
      'dataset_categories_en.json',
      'dataset_categories_np.json',
      'dataset_districts_en.json',
      'dataset_districts_np.json',
      'dataset_municipalities_en.json',
      'dataset_municipalities_np.json',
      'dataset_provinces_en.json',
      'dataset_provinces_np.json',
      'LICENSE',
    ],
  ),
  'nepali-geo-pro-max': SourceConfig(
    name: 'nepali-geo-pro-max',
    baseUrl:
        'https://raw.githubusercontent.com/l3lackcurtains/nepali-geo-pro-max/main',
    files: [
      'src_data_provinces.ts',
      'src_data_districts.ts',
      'src_data_local-units.ts',
      'src_data_legacy-districts.ts',
      'src_data_zones.ts',
      'src_data_regions.ts',
      'src_data_postal-codes.ts',
      'src_data_postal-codes-2025.ts',
      'LICENSE',
    ],
  ),
  'open-admin-data': SourceConfig(
    name: 'open-admin-data',
    baseUrl:
        'https://raw.githubusercontent.com/open-admin-data/nepal-administrative-divisions/main',
    files: [
      'data_all-province.json',
      'data_all-district.json',
      'data_all-local_unit.json',
      'data_schema.json',
      'LICENSE',
    ],
  ),
  'cbs-codes': SourceConfig(
    name: 'cbs-codes',
    baseUrl:
        'https://api.opendatanepal.com/dataset/22870675-146d-4e4f-8848-2216380170de/resource',
    files: [
      'cbs_districts.csv',
      'cbs_local_bodies.csv',
      'cbs_states.csv',
      'LICENSE',
    ],
    customUrlBuilder: (file) {
      final resourceIds = {
        'cbs_districts.csv': 'de973922-7b56-4521-b6a4-aa3de7f8d8a2',
        'cbs_local_bodies.csv': 'e33aa0f3-72de-4074-a38b-c6a1bf55d9a8',
        'cbs_states.csv': '37aa60f6-cbbe-43fd-b581-6864b72744ae',
      };
      if (file == 'LICENSE') return null;
      final id = resourceIds[file];
      if (id == null) return null;
      return 'https://api.opendatanepal.com/dataset/22870675-146d-4e4f-8848-2216380170de/resource/$id/download/${file.split('/').last}';
    },
  ),
  'mofaga': SourceConfig(
    name: 'mofaga',
    baseUrl: '',
    files: [
      'mofaga_all.json',
    ],
    manual: true,
  ),
};

class SourceConfig {
  const SourceConfig({
    required this.name,
    required this.baseUrl,
    required this.files,
    this.manual = false,
    this.customUrlBuilder,
  });

  final String name;
  final String baseUrl;
  final List<String> files;
  final bool manual;
  final String? Function(String)? customUrlBuilder;
}

class PinnedFile {
  const PinnedFile(this.rel, this.hash, this.size);

  final String rel; // e.g. 'abinrimal/provinces.json'
  final String hash; // uppercase SHA-256 hex
  final int size; // bytes
}

void main(List<String> args) async {
  final verifyOnly = args.contains('--verify');
  final listOnly = args.contains('--list');

  // Parse the manifest
  final manifest = File('data/PROVENANCE.sha256');
  if (!manifest.existsSync()) {
    stderr.writeln('ERROR: data/PROVENANCE.sha256 not found');
    exit(2);
  }

  final pinned = <String, PinnedFile>{};
  final entry = RegExp(r'^([0-9A-Fa-f]{64})\s+(\d+)\s+(\S+)\s*$');
  for (final line in manifest.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final m = entry.firstMatch(line);
    if (m == null) {
      stderr.writeln('WARNING: malformed manifest line: $line');
      continue;
    }
    final rel = m.group(3)!;
    pinned[rel] =
        PinnedFile(rel, m.group(1)!.toUpperCase(), int.parse(m.group(2)!));
  }

  if (listOnly) {
    stdout.writeln('Files to be fetched/verified (${pinned.length} total):');
    for (final rel in pinned.keys.toList()..sort()) {
      final p = pinned[rel]!;
      final src = _findSource(p.rel);
      stdout.writeln(
          '  ${src?.name ?? 'UNKNOWN'}  ${p.rel}  (${p.size} B)  ${p.hash.substring(0, 16)}...');
    }
    return;
  }

  // Verify-only mode: check against manifest, no download
  if (verifyOnly) {
    final rawDir = Directory('data/_raw');
    if (!rawDir.existsSync()) {
      stderr.writeln('data/_raw/ not present — cannot verify');
      exit(1);
    }
    for (final p in pinned.values) {
      final file = File('data/_raw/${p.rel}');
      if (!file.existsSync()) {
        stdout.writeln('MISSING: ${p.rel}');
        continue;
      }
      final bytes = file.readAsBytesSync();
      final gotHash = sha256.convert(bytes).toString().toUpperCase();
      if (gotHash != p.hash) {
        stdout.writeln(
            'MISMATCH: ${p.rel} (got ${gotHash.substring(0, 16)}… != ${p.hash.substring(0, 16)}…)');
      } else if (bytes.length != p.size) {
        stdout
            .writeln('SIZE-DRIFT: ${p.rel} (${bytes.length} B != ${p.size} B)');
      } else {
        stdout.writeln('OK: ${p.rel}');
      }
    }
    return;
  }

  // Full download mode
  final httpClient = HttpClient();
  httpClient.connectionTimeout = const Duration(seconds: 30);
  httpClient.idleTimeout = const Duration(seconds: 60);

  int ok = 0, failed = 0, skipped = 0;

  for (final p in pinned.values.toList()
    ..sort((a, b) => a.rel.compareTo(b.rel))) {
    final src = _findSource(p.rel);
    if (src == null) {
      stdout.writeln('  [SKIP] ${p.rel} - no source mapping');
      skipped++;
      continue;
    }
    if (src.manual) {
      stdout.writeln('  [MANUAL] ${p.rel} - ${src.name} (no public URL)');
      skipped++;
      continue;
    }

    final url = src.customUrlBuilder != null
        ? src.customUrlBuilder!(p.rel)
        : '${src.baseUrl}/${p.rel.split('/').last}';
    if (url == null) {
      stdout.writeln('  [SKIP] ${p.rel} - no URL builder for ${src.name}');
      skipped++;
      continue;
    }

    stdout.write('  [FETCH] ${p.rel} ... ');
    try {
      await _downloadWithRetry(
          httpClient, url, 'data/_raw/${p.rel}', p.size, p.hash);
      stdout.writeln('OK (${p.size} B, ${p.hash.substring(0, 16)}...)');
      ok++;
    } catch (e) {
      stdout.writeln('FAILED');
      stderr.writeln('  Error fetching ${p.rel}: $e');
      failed++;
    }
  }

  // Final verification
  stdout.writeln('\n=== VERIFICATION ===');
  int verified = 0, mismatch = 0, missing = 0;
  for (final p in pinned.values) {
    final file = File('data/_raw/${p.rel}');
    if (!file.existsSync()) {
      missing++;
      continue;
    }
    final bytes = file.readAsBytesSync();
    final gotHash = sha256.convert(bytes).toString().toUpperCase();
    if (gotHash != p.hash) {
      stdout.writeln(
          'MISMATCH: ${p.rel} (${gotHash.substring(0, 16)}… != ${p.hash.substring(0, 16)}…)');
      mismatch++;
    } else if (bytes.length != p.size) {
      stdout.writeln('SIZE-DRIFT: ${p.rel} (${bytes.length} B != ${p.size} B)');
      mismatch++;
    } else {
      verified++;
    }
  }

  stdout.writeln('\n=== SUMMARY ===');
  stdout.writeln('  Fetched OK:     $ok');
  stdout.writeln('  Failed:         $failed');
  stdout.writeln('  Skipped:        $skipped');
  stdout.writeln('  Verified OK:    $verified');
  stdout.writeln('  Missing:        $missing');
  stdout.writeln('  Mismatch/Drift: $mismatch');

  if (failed > 0 || mismatch > 0 || missing > 0) {
    exit(1);
  }
  exit(0);
}

SourceConfig? _findSource(String rel) {
  final prefix = rel.split('/').first;
  return sources[prefix];
}

Future<void> _downloadWithRetry(
  HttpClient client,
  String url,
  String destPath,
  int expectedSize,
  String expectedHash,
) async {
  final destFile = File(destPath);
  await destFile.parent.create(recursive: true);

  const maxRetries = 3;
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final sink = destFile.openWrite();
      int downloaded = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
      }
      await sink.flush();
      await sink.close();

      // Verify size
      if (downloaded != expectedSize) {
        await destFile.delete();
        throw StateError(
            'Size mismatch: downloaded $downloaded B, expected $expectedSize B');
      }

      // Verify hash
      final bytes = await destFile.readAsBytes();
      final gotHash = sha256.convert(bytes).toString().toUpperCase();
      if (gotHash != expectedHash) {
        await destFile.delete();
        throw StateError(
            'Hash mismatch: got ${sha256.convert(bytes).toString().toUpperCase().substring(0, 16)}…, expected ${expectedHash.substring(0, 16)}…');
      }

      return; // Success
    } catch (e) {
      if (destFile.existsSync()) await destFile.delete();
      if (attempt == maxRetries) rethrow;
      stderr.writeln(
          '    Attempt $attempt failed: $e — retrying in ${attempt * 2}s...');
      await Future.delayed(Duration(seconds: attempt * 2));
    }
  }
}
