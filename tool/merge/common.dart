// tool/merge/common.dart
//
// Shared helpers for the merge tooling (inventory.dart, verify_codes.dart,
// and later the Step 4 matcher). Single source of truth for: provenance
// verification, TypeScript data-module parsing, name normalisation, the
// canonical-district folds, Levenshtein suggestions, and Devanagari numeral
// parsing.
//
// Nothing in here knows about any particular merge step; it only parses,
// normalises and verifies.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// ---------------------------------------------------------------------------
// Provenance
// ---------------------------------------------------------------------------

/// Verifies every file pinned in data/PROVENANCE.sha256 against data/_raw/.
/// Returns the list of problems (empty = verified). Manifest lines look like:
/// `<sha256-hex>  <bytes>  <repo-relative-path-under-data/_raw>`.
List<String> verifyProvenance() {
  final problems = <String>[];
  final manifest = File('data/PROVENANCE.sha256');
  if (!manifest.existsSync()) {
    return ['data/PROVENANCE.sha256 is missing — cannot verify inputs'];
  }
  final rawDir = Directory('data/_raw');
  if (!rawDir.existsSync()) {
    return [
      'data/_raw/ is missing — nothing to verify. '
          'Re-fetch the sources per data/SOURCES.md, then re-run.',
    ];
  }
  final entry = RegExp(
    r'^([0-9A-Fa-f]{64})\s+(\d+)\s+(\S+)\s*$',
    multiLine: false,
  );
  final pinned = <String>{};
  for (final line in manifest.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final m = entry.firstMatch(line);
    if (m == null) {
      problems.add('manifest line is malformed: $line');
      continue;
    }
    final wantHash = m.group(1)!.toUpperCase();
    final wantSize = int.parse(m.group(2)!);
    final rel = m.group(3)!;
    pinned.add(rel);
    final file = File('data/_raw/$rel');
    if (!file.existsSync()) {
      problems.add(
        'MISSING: data/_raw/$rel (pinned in manifest, not on disk)',
      );
      continue;
    }
    final bytes = file.readAsBytesSync();
    final gotHash = sha256.convert(bytes).toString().toUpperCase();
    if (gotHash != wantHash) {
      problems.add(
        'MISMATCH: data/_raw/$rel '
        '(manifest ${wantHash.substring(0, 16)}… != disk ${gotHash.substring(0, 16)}…) — '
        'upstream changed; re-review before merging',
      );
    } else if (bytes.length != wantSize) {
      problems.add(
        'SIZE-DRIFT: data/_raw/$rel '
        '(manifest $wantSize B != disk ${bytes.length} B with matching hash?!)',
      );
    }
  }
  for (final entity in rawDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path
        .replaceFirst(RegExp(r'^data[/\\]_raw[/\\]'), '')
        .replaceAll('\\', '/');
    if (rel == 'PROVENANCE.sha256') continue;
    if (!pinned.contains(rel)) {
      problems.add(
        'UNPINNED: data/_raw/$rel exists on disk but is not in '
        'the manifest — untracked input; pin it or remove it',
      );
    }
  }
  return problems;
}

// ---------------------------------------------------------------------------
// Minimal TypeScript data-module parsing
// ---------------------------------------------------------------------------

/// Removes `//` and `/* */` comments while respecting string literals, so a
/// `//` inside a quoted value is never mistaken for a comment.
String stripTsComments(String s) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < s.length) {
    final c = s[i];

    if (quote != null) {
      if (c == r'\') {
        out.write(c);
        if (i + 1 < s.length) out.write(s[i + 1]);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      out.write(c);
      i++;
      continue;
    }

    if (c == '"' || c == "'" || c == '`') {
      quote = c;
      out.write(c);
      i++;
      continue;
    }

    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
      continue;
    }

    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      i += 2;
      while (i + 1 < s.length && !(s[i] == '*' && s[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}

/// Strips comments, numeric separators and imports/type declarations from a
/// TypeScript data module, leaving roughly JSON-compatible source.
String cleanTsModule(String source) {
  var s = source;
  s = s.replaceAll(RegExp(r'^import[^\n]*\n', multiLine: true), '');
  s = s.replaceAll(
    RegExp(r'^(?:export\s+)?interface[^}]*\}\s*', multiLine: true),
    '',
  );
  // Function bodies (legacy-districts.ts defines a slugify helper).
  s = s.replaceAll(
    RegExp(r'^(?:export\s+)?function[\s\S]*?\n\}\s*', multiLine: true),
    '',
  );
  s = stripTsComments(s);
  s = s.replaceAllMapped(RegExp(r'(?<=\d)_(?=\d)'), (_) => '');
  return s;
}

/// Extracts the first container literal (array or object) assigned to a
/// top-level `const`, using bracket-depth scanning so a *second* declaration
/// later in the module cannot overshoot the first.
String extractFirstContainer(String cleaned) {
  final assign = RegExp(r'=\s*([\[{])').firstMatch(cleaned);
  if (assign == null) {
    throw const FormatException(
      'could not locate container literal in TS module',
    );
  }
  final open = assign.group(1)!;
  final close = open == '[' ? ']' : '}';
  final start = assign.end - 1;

  var depth = 0;
  for (var i = start; i < cleaned.length; i++) {
    final c = cleaned[i];
    if (c == open) {
      depth++;
    } else if (c == close) {
      depth--;
      if (depth == 0) return cleaned.substring(start, i + 1);
    }
  }
  throw const FormatException('unbalanced container literal in TS module');
}

/// Quotes unquoted object keys and removes trailing commas.
String toJsonCompatible(String s) {
  var out = s.replaceAllMapped(
    RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)'),
    (m) => '${m[1]}"${m[2]}"${m[3]}',
  );
  out = out.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);
  return out;
}

dynamic decodeTsJson(String json, String path) {
  try {
    return jsonDecode(json);
  } on FormatException catch (e) {
    throw FormatException('$path: $e');
  }
}

List<Map<String, dynamic>> loadTsArray(String path) {
  final decoded = decodeTsJson(
    toJsonCompatible(
      extractFirstContainer(
        cleanTsModule(File(path).readAsStringSync()),
      ),
    ),
    path,
  );
  if (decoded is! List) throw FormatException('$path is not an array');
  return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

Map<String, dynamic> loadTsObject(String path) {
  final decoded = decodeTsJson(
    toJsonCompatible(
      extractFirstContainer(
        cleanTsModule(File(path).readAsStringSync()),
      ),
    ),
    path,
  );
  if (decoded is! Map) throw FormatException('$path is not an object');
  return decoded.cast<String, dynamic>();
}

List<Map<String, dynamic>> loadJsonArray(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! List) throw FormatException('$path is not a JSON array');
  return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
}

// ---------------------------------------------------------------------------
// CSV loading (CRLF-safe; the CBS harvest ships CRLF bytes, pinned as-is)
// ---------------------------------------------------------------------------

/// Splits [text] into lines tolerating LF, CRLF and lone-CR endings, and
/// drops a single trailing empty line. Returns lines WITHOUT terminators.
List<String> splitCsvLines(String text) {
  final lines = text.split(RegExp(r'\r\n|\n|\r'));
  if (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// Parses a headerless-or-headered CSV with NO quoted fields (verified per
/// file: zero `"` bytes) into maps keyed by [headers]. Fails loudly on any
/// row whose field count differs — a shifted or re-exported file must never
/// parse silently.
List<Map<String, String>> loadSimpleCsv(String path, List<String> headers) {
  final text = File(path).readAsStringSync();
  final lines = splitCsvLines(text);
  if (lines.isEmpty) throw FormatException('$path is empty');
  final rows = <Map<String, String>>[];
  // Skip the header row after validating it has the expected width.
  final headerFields = lines.first.split(',');
  if (headerFields.length != headers.length) {
    throw FormatException(
      '$path: header has ${headerFields.length} fields, '
      'expected ${headers.length}',
    );
  }
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final fields = line.split(',');
    if (fields.length != headers.length) {
      throw FormatException(
        '$path row ${i + 1}: ${fields.length} fields, '
        'expected ${headers.length} (shifted file?)',
      );
    }
    rows.add({
      for (var k = 0; k < headers.length; k++) headers[k]: fields[k].trim(),
    });
  }
  return rows;
}

// ---------------------------------------------------------------------------
// Name normalisation
// ---------------------------------------------------------------------------

final devaRegex = RegExp('[\u0900-\u097F]');

String normDistrict(String? raw) {
  if (raw == null) return '';
  return raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Canonical district form for MATCHING ONLY (never for display or storage).
/// Folds evidenced spelling variants to one key so cross-source agreement is
/// not split by district naming. Each fold is backed by an observed variant:
///
/// - acham -> achham (sagautam5 calls Achham "Acham")
/// - pachthar -> panchthar, ramechap -> ramechhap, parwat -> parbat
///   (sagautam5 spellings; nepali-geo-pro-max documents the same four
///   normalizations in its districts.ts header)
/// - dhanusa -> dhanusha, chitawan -> chitwan, tanahu -> tanahun,
///   kapilbastu -> kapilvastu, nawalparasi east -> nawalpur,
///   parasi (nawalparasi west) -> nawalparasi west
///   (open-admin-data spellings vs ours; CBS harvest uses the same
///   uppercase variants: CHITAWAN, DHANUSA, TANAHU, KAPILBASTU,
///   NAWALPARASI EAST/WEST, RUKUM EAST/WEST)
/// - eastern rukum -> rukum east, western rukum -> rukum west,
///   parasi -> nawalparasi west (sagautam5 / geo-pro-max name the 2017 splits
///   "Eastern/Western Rukum" and "Parasi" where abinrimal and ours use
///   "Rukum East/West" and "Parasi (Nawalparasi West)" / "Nawalparasi West")
/// - nawalparari east -> nawalpur (abinrimal typo for "Nawalparasi East";
///   the district is Nawalpur in ours, sagautam5 and geo-pro-max)
String canonDistrict(String? raw) {
  final n = normDistrict(raw);
  const folds = {
    'acham': 'achham',
    'pachthar': 'panchthar',
    'ramechap': 'ramechhap',
    'parwat': 'parbat',
    'dhanusa': 'dhanusha',
    'chitawan': 'chitwan',
    'tanahu': 'tanahun',
    'nawalparasi east': 'nawalpur',
    'nawalparari east': 'nawalpur',
    'parasi (nawalparasi west)': 'nawalparasi west',
    'parasi': 'nawalparasi west',
    'kapilbastu': 'kapilvastu',
    'eastern rukum': 'rukum east',
    'western rukum': 'rukum west',
  };
  return folds[n] ?? n;
}

String stripParens(String s) => s
    .replaceAll(RegExp(r'\([^)]*\)'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String stripSuffix(String s) {
  for (final suffix in const [
    'sub-metropolitan city',
    'sub metropolitan city',
    'metropolitan city',
    'rural municipality',
    'municipality',
  ]) {
    if (s.endsWith(' $suffix')) {
      return s.substring(0, s.length - suffix.length - 1).trim();
    }
    if (s == suffix) return '';
  }
  return s;
}

String flatToken(String s) => s.replaceAll(RegExp(r"[\s\-'.]"), '');

/// Matching key used across sources: `[district]|[name]`, both flattened.
/// Flattening = lowercase, type suffix and "(...)" groups stripped, then all
/// spaces, hyphens, apostrophes and dots removed. This absorbs "Mai Jogmai"
/// vs "Maijogmai" and "Bhojpur Municipality" vs "Bhojpur", but NOT genuine
/// spelling differences ("Shadananda" vs "Shadanand"), which are reported as
/// fuzzy suggestions instead of silent matches.
String palikaKey(String? district, String? name) =>
    '${flatToken(canonDistrict(district))}|${flatToken(stripSuffix(stripParens((name ?? '').toLowerCase().trim())))}';

/// Lighter normalisation for spelling-variant reporting: case and whitespace
/// only, suffixes and punctuation kept. Two records sharing a flat key but
/// differing here expose a suffix/punctuation variant (e.g. "Bhojpur" vs
/// "Bhojpur Municipality").
String looseName(String? raw) {
  if (raw == null) return '';
  return raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Levenshtein distance over runes (safe for Devanagari). Candidates whose
/// lengths differ by more than [max] can never be within [max], so callers
/// should prefilter on length to keep the national scans cheap.
int levenshtein(String a, String b, [int max = 2]) {
  final ar = a.runes.toList();
  final br = b.runes.toList();
  if ((ar.length - br.length).abs() > max) return max + 1;
  var prev = List<int>.generate(br.length + 1, (j) => j);
  for (var i = 1; i <= ar.length; i++) {
    final cur = <int>[i];
    for (var j = 1; j <= br.length; j++) {
      final cost = ar[i - 1] == br[j - 1] ? 0 : 1;
      var v = prev[j] + 1;
      final ins = cur[j - 1] + 1;
      if (ins < v) v = ins;
      final sub = prev[j - 1] + cost;
      if (sub < v) v = sub;
      cur.add(v);
    }
    prev = cur;
  }
  return prev[br.length];
}

/// Best fuzzy suggestion for a key missing from [candidates]: same-district
/// name parts within Levenshtein distance 2 first, then national.
/// Returns null when nothing is within distance 2. Suggestions are for human
/// review in doc/REVIEW.md — never auto-applied.
String? suggestKey(String missingKey, Set<String> candidates) {
  final parts = missingKey.split('|');
  final missingDist = parts[0];
  final missingName = parts.length > 1 ? parts[1] : '';
  String? best;
  var bestD = 3;
  String cname(String c) {
    final cp = c.split('|');
    return cp.length > 1 ? cp[1] : '';
  }

  for (final pass in const [true, false]) {
    for (final c in candidates) {
      if (pass && c.split('|')[0] != missingDist) continue;
      final d = levenshtein(missingName, cname(c), 2);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    if (best != null) return '$best (d=$bestD)';
  }
  return null;
}

const _devaDigits = '०१२३४५६७८९';

/// Converts a Devanagari-numeral string (e.g. "१४") — or a plain ASCII-digit
/// string — to int. Returns null when the string holds anything else, so
/// callers can distinguish "missing" from "unparseable" instead of silently
/// treating both as zero.
int? devaDigitsToInt(Object? value) {
  if (value is int) return value;
  if (value is! String) return null;
  final s = value.trim();
  if (s.isEmpty) return null;
  final out = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final idx = _devaDigits.indexOf(ch);
    if (idx >= 0) {
      out.write(idx);
    } else if (r >= 48 && r <= 57) {
      out.write(ch);
    } else {
      return null;
    }
  }
  return int.tryParse(out.toString());
}
