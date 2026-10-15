// lib/src/nepal_admin_api_base.dart
//
// Core models and the query API for Nepal's administrative divisions.

import 'nepal_data.dart';

/// The type of a local body (palika) of Nepal.
enum LocalBodyType {
  /// A Metropolitan City — 6 exist nationwide.
  metropolitan('Metro', 'Metropolitan City'),

  /// A Sub-Metropolitan City — 11 exist nationwide.
  subMetropolitan('Sub-Metro', 'Sub-Metropolitan City'),

  /// A Municipality — 276 exist nationwide.
  municipality('M', 'Municipality'),

  /// A Rural Municipality — 460 exist nationwide.
  ruralMunicipality('RM', 'Rural Municipality'),

  /// Fallback for deserialization misses.
  unknown('Unknown', 'Unknown');

  const LocalBodyType(this.shortName, this.fullName);

  /// The abbreviation used by the dataset, e.g. 'RM'.
  final String shortName;

  /// The human-readable name, e.g. 'Rural Municipality'.
  final String fullName;

  /// Resolves a dataset abbreviation to its enum value.
  static LocalBodyType fromShort(String? value) =>
      LocalBodyType.values.firstWhere((t) => t.shortName == value,
          orElse: () => LocalBodyType.unknown);
}

/// How much evidence stands behind a [LocalBody.cbsCode].
///
/// Replaces the old boolean-only story. [LocalBody.cbsCodeVerified] remains
/// available and is simply `confidence == CbsCodeConfidence.verified`, so
/// existing code keeps working unchanged.
enum CbsCodeConfidence {
  /// Doubly-attested: the postal-2025 code list and the CBS harvest name the
  /// same code for the same entity. [LocalBody.cbsCodeVerified] is true.
  verified('verified'),

  /// A single attestation from the authoritative CBS roster: exactly one
  /// same-district row of the same palika type whose normalized name matches,
  /// or a pairing forced by elimination inside a district whose roster matches
  /// the CBS roster type-for-type. Usable for joins, but not doubly-attested.
  singleSource('singleSource'),

  /// No defensible code. [LocalBody.cbsCode] is null — on purpose, never
  /// guessed.
  unverified('unverified');

  const CbsCodeConfidence(this.wireName);

  /// The value used in the dataset JSON.
  final String wireName;

  /// Resolves a dataset value to its enum value.
  static CbsCodeConfidence fromWire(String? value) {
    for (final t in values) {
      if (t.wireName == value) return t;
    }
    return CbsCodeConfidence.unverified;
  }

  /// Whether a code is attached at all.
  bool get hasCode => this != CbsCodeConfidence.unverified;
}

/// Aggregate counts for one province.
class ProvinceStats {
  /// Districts in the province.
  final int districts;

  /// Metropolitan cities.
  final int metro;

  /// Sub-metropolitan cities.
  final int subMetro;

  /// Municipalities.
  final int mun;

  /// Rural municipalities.
  final int ruralMun;

  /// Total local bodies.
  final int total;

  /// Total wards.
  final int wards;

  const ProvinceStats({
    required this.districts,
    required this.metro,
    required this.subMetro,
    required this.mun,
    required this.ruralMun,
    required this.total,
    required this.wards,
  });

  /// Serializes these province-level counters. Round-trips with the raw map.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'districts': districts,
        'metro': metro,
        'subMetro': subMetro,
        'municipalities': mun,
        'ruralMunicipalities': ruralMun,
        'total': total,
        'wards': wards,
      };
}

/// A local body (palika): metropolitan, sub-metropolitan, municipality
/// or rural municipality. The smallest administrative unit in the package.
class LocalBody {
  /// Display name, e.g. 'Bharatpur'.
  final String name;

  /// Devanagari name, e.g. 'भारतपुर उपमहानगरपालिका'. Null when no source
  /// carries it (22 of 753) — never transliterated or guessed.
  ///
  /// For display prefer [nameNeOrName], which falls back to [name].
  final String? nameNe;

  /// Whether [nameNe] was corroborated by two independent sources. When true
  /// the Devanagari spelling is settled; when false it is one source's
  /// rendering of an English name we identified, which is still the best
  /// available and worth using.
  final bool nameNeVerified;

  /// Palika type (metro, sub-metro, municipality, rural).
  final LocalBodyType type;

  /// Owning district, e.g. 'Chitwan'.
  final String districtName;

  /// Owning province, e.g. 'Bagmati'.
  final String provinceName;

  /// CBS 5-digit code (PDDPP format: P=province 1-7, DD=district 01-77, PP=palika 01-99).
  /// Null if not verified against CBS/MoFAGA sources.
  final int? cbsCode;

  /// Whether the [cbsCode] is verified (doubly-attested by CBS + postal-2025).
  ///
  /// Equivalent to `cbsCodeConfidence == CbsCodeConfidence.verified`. Prefer
  /// reading [cbsCodeConfidence] when you care about single-source codes too.
  final bool cbsCodeVerified;

  /// How strongly [cbsCode] is attested. Null in [cbsCode] means
  /// [CbsCodeConfidence.unverified].
  final CbsCodeConfidence cbsCodeConfidence;

  /// Approximate centroid latitude (WGS84). Null when not yet geocoded.
  final double? lat;

  /// Approximate centroid longitude (WGS84). Null when not yet geocoded.
  final double? lng;

  /// Provenance of the coordinates, e.g. 'open-admin-data', 'osm-nominatim'.
  final String? geoSource;

  /// Number of wards in this local body. Null when not verified against
  /// ward-count sources (see `wardsVerified`).
  final int? wards;

  /// Whether [wards] is doubly-attested (sagautam5 + geo-pro-max agree,
  /// or a documented human decision in decisions_wards_manual.json).
  final bool wardsVerified;

  /// Official website of the local body's office. **Single-source**
  /// (Ministry of Federal Affairs and General Administration harvest).
  /// Absent for 382 of 753 - published as null, never synthesised.
  final String? website;

  /// Official contact email. Single-source; absent for most palikas.
  final String? email;

  /// Official contact telephone. Single-source; absent for most palikas.
  final String? phone;

  /// Nepal Post postal codes covering this local body. Single-source
  /// (open-admin-data); absent for 280 of 753.
  final List<String> zipCodes;

  /// Whether this local body publishes a contact address of some kind.
  bool get hasContact => website != null || email != null || phone != null;

  /// Creates a local body. Prefer the package's own lookups
  /// ([NepalAdminApi.getLocalBodyByCbs]) over constructing one by hand.
  const LocalBody({
    required this.name,
    this.nameNe,
    this.nameNeVerified = false,
    required this.type,
    required this.districtName,
    required this.provinceName,
    this.cbsCode,
    this.cbsCodeVerified = false,
    this.cbsCodeConfidence = CbsCodeConfidence.unverified,
    this.lat,
    this.lng,
    this.geoSource,
    this.wards,
    this.wardsVerified = false,
    this.website,
    this.email,
    this.phone,
    this.zipCodes = const [],
  });

  /// Full display name of the type, e.g. 'Rural Municipality'.
  String get typeName => type.fullName;

  /// The Devanagari name when available, otherwise the English one.
  ///
  /// Safe to render directly in a bilingual UI; you never have to null-check.
  String get nameNeOrName => nameNe ?? name;

  /// The same label in both scripts, e.g. 'Bharatpur · भारतपुर'. Handy for
  /// search results and admin tables. Falls back to a single script when the
  /// other is unavailable, so it never renders a dangling separator.
  String get displayBoth => nameNe == null ? name : '$name · $nameNe';

  /// Whether this is an urban local government.
  bool get isUrban =>
      type == LocalBodyType.metropolitan ||
      type == LocalBodyType.subMetropolitan ||
      type == LocalBodyType.municipality;

  /// Whether this is a rural municipality.
  bool get isRural => type == LocalBodyType.ruralMunicipality;

  /// Whether approximate map coordinates are available.
  bool get hasCoordinates => lat != null && lng != null;

  /// Whether this local body carries a CBS code at all, of any confidence.
  ///
  /// 744 of 753 do. Use this rather than `cbsCode != null` only when you
  /// genuinely mean "has any code"; a join against government datasets should
  /// prefer [cbsCodeConfidence] to decide how much to trust it.
  bool get hasCbsCode => cbsCode != null;

  /// Whether this local body is mapped **and** carries a code, i.e. it can be
  /// plotted and joined.
  bool get isCodeAndCoordinateMapped => hasCbsCode && hasCoordinates;

  /// The CBS code as a fixed-width string, e.g. `'031304'`. Zero-padded to the
  /// 5-digit PDDPP width so string joins against government files line up.
  /// Null when no code is attested.
  String? get cbsCodeString => cbsCode?.toString().padLeft(5, '0');

  /// The district's 3-digit code as a string, derived from this body when it
  /// carries one. E.g. Bharatpur (31304) -> '313'.
  String? get districtCbsCodeString =>
      cbsCode == null ? null : (cbsCode! ~/ 100).toString().padLeft(3, '0');

  /// Human-readable hierarchical path, e.g. 'Bharatpur, Chitwan, Bagmati'.
  /// Useful for dropdowns, breadcrumbs and disambiguating duplicate names.
  String get fullPath => '$name, $districtName, $provinceName';

  /// Serializes this palika. Round-trips with [LocalBody.fromJson]; absent
  /// fields stay absent rather than becoming explicit nulls.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (nameNe != null) 'nameNe': nameNe,
        if (nameNeVerified) 'nameNeVerified': nameNeVerified,
        'type': type.shortName,
        'district': districtName,
        'province': provinceName,
        if (cbsCode != null) 'cbsCode': cbsCode,
        if (cbsCodeVerified) 'cbsCodeVerified': cbsCodeVerified,
        if (cbsCodeConfidence.hasCode)
          'cbsCodeConfidence': cbsCodeConfidence.wireName,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (geoSource != null) 'geoSource': geoSource,
        if (wards != null) 'wards': wards,
        if (wardsVerified) 'wardsVerified': wardsVerified,
        if (website != null) 'website': website,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (zipCodes.isNotEmpty) 'zipCodes': zipCodes,
      };

  /// Rebuilds a [LocalBody] from [toJson] output (round-trip safe).
  factory LocalBody.fromJson(Map<String, dynamic> json) {
    final confidence =
        CbsCodeConfidence.fromWire(json['cbsCodeConfidence'] as String?);
    final code = json['cbsCode'] as int?;
    // Keep the flag and the tier consistent no matter which one the input
    // carried, so a hand-built JSON map can never claim a code is verified
    // while its tier says otherwise (or vice versa).
    final verified = (json['cbsCodeVerified'] as bool? ?? false) ||
        confidence == CbsCodeConfidence.verified;
    return LocalBody(
      name: json['name'] as String,
      nameNe: json['nameNe'] as String?,
      nameNeVerified: json['nameNeVerified'] as bool? ?? false,
      type: LocalBodyType.fromShort(json['type'] as String?),
      districtName: json['district'] as String? ?? '',
      provinceName: json['province'] as String? ?? '',
      cbsCode: code,
      cbsCodeVerified: verified && code != null,
      cbsCodeConfidence: code == null
          ? CbsCodeConfidence.unverified
          : (verified ? CbsCodeConfidence.verified : confidence),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      geoSource: json['geoSource'] as String?,
      wards: json['wards'] as int?,
      wardsVerified: json['wardsVerified'] as bool? ?? false,
      website: json['website'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      zipCodes: [
        for (final z in (json['zipCodes'] as List? ?? const [])) '$z',
      ],
    );
  }

  /// Value equality over the identifying fields, so models can be compared in
  /// tests and put in sets/maps. Coordinates and provenance are excluded: they
  /// are derived data that may be refined without changing identity.
  @override
  bool operator ==(Object other) =>
      other is LocalBody &&
      other.name == name &&
      other.type == type &&
      other.districtName == districtName &&
      other.provinceName == provinceName &&
      other.cbsCode == cbsCode;

  @override
  int get hashCode =>
      Object.hash(name, type, districtName, provinceName, cbsCode);

  /// Compact display form, e.g. 'Bharatpur (Metro)'.
  @override
  String toString() => '$name (${type.shortName})';
}

/// A district (77 nationwide), owning its local bodies.
class District {
  /// Display name, e.g. 'Chitwan'.
  final String name;

  /// Devanagari name, e.g. 'चितवन'. Present for all 77 districts.
  final String? nameNe;

  /// Whether [nameNe] was corroborated by two independent sources.
  final bool nameNeVerified;

  /// The CBS 3-digit district code (e.g., 101 for Taplejung, 306 for Kathmandu).
  /// First digit = province (1-7), next two = district within province.
  final int? cbsCode;

  /// The district's administrative headquarters, e.g. 'Bharatpur' for Chitwan.
  ///
  /// **Single-source** (sagautam5). Present for all 77 districts.
  final String? headquarter;

  /// Area in square kilometres. **Single-source** (sagautam5); treat as an
  /// approximate figure for anything load-bearing.
  final double? areaSqKm;

  /// The district's official website. **Single-source** (sagautam5).
  final String? website;

  final List<LocalBody> _units;
  String _provinceName;

  /// Creates a district. Prefer the package's own lookups
  /// ([NepalAdminApi.getDistrictByName]) over constructing one by hand.
  District({
    required this.name,
    this.nameNe,
    this.nameNeVerified = false,
    this.cbsCode,
    this.headquarter,
    this.areaSqKm,
    this.website,
    required List<LocalBody> units,
    String provinceName = '',
  })  : _units = units,
        _provinceName = provinceName;

  /// A local body in this district by exact name (case-insensitive), or null.
  /// Faster and more precise than scanning [search] for one district.
  LocalBody? localBodyByName(String name) {
    final lower = name.toLowerCase();
    for (final b in _units) {
      if (b.name.toLowerCase() == lower) return b;
    }
    return null;
  }

  /// The Devanagari name when available, otherwise the English one.
  String get nameNeOrName => nameNe ?? name;

  /// Both scripts in one label, e.g. 'Chitwan · चितवन'.
  String get displayBoth => nameNe == null ? name : '$name · $nameNe';

  /// Called by [Province] when this district is attached to it.
  /// Public on purpose: the data lives in nepal_data.dart (another library).
  /// Prefer constructing [District] with [provinceName] directly.
  void setProvinceContext(String provinceName) {
    _provinceName = provinceName;
  }

  /// The province this district belongs to.
  String get provinceName => _provinceName;

  /// The district's local bodies.
  List<LocalBody> get localBodies => _units;

  /// Number of local bodies in this district.
  int get localBodyCount => _units.length;

  /// Total wards in this district (sums verified counts; unverified
  /// units contribute 0 — use [verifiedLocalBodies] for exact sums).
  int get wards => _units.fold<int>(0, (sum, b) => sum + (b.wards ?? 0));

  /// How many local bodies in this district carry a ward count, and how many
  /// do not. `missing` is 0 for most districts; the handful with documented
  /// roster defects are listed in the CHANGELOG.
  ({int withCount, int missing, int total}) get verifiedWardCoverage => (
        withCount: _units.where((b) => b.wards != null).length,
        missing: _units.where((b) => b.wards == null).length,
        total: _units.length,
      );

  /// Whether every local body in this district has a doubly-attested ward
  /// count. True for most districts; false for the 8 palikas documented as
  /// roster defects.
  bool get wardsFullyVerified =>
      _units.every((b) => b.wards != null && b.wardsVerified);

  /// Local bodies of one [type] in this district.
  List<LocalBody> localBodiesByType(LocalBodyType type) => [
        for (final b in _units)
          if (b.type == type) b
      ];

  /// Only CBS-verified local bodies in this district.
  List<LocalBody> get verifiedLocalBodies => [
        for (final b in _units)
          if (b.cbsCodeVerified) b
      ];

  /// Serializes this district, including its local bodies.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        if (nameNe != null) 'nameNe': nameNe,
        if (nameNeVerified) 'nameNeVerified': nameNeVerified,
        'province': _provinceName,
        if (cbsCode != null) 'cbsCode': cbsCode,
        if (headquarter != null) 'headquarter': headquarter,
        if (areaSqKm != null) 'areaSqKm': areaSqKm,
        if (website != null) 'website': website,
        'localBodies': [for (final b in _units) b.toJson()],
      };

  /// Rebuilds a [District] from [toJson] output.
  ///
  /// Unlike the constructor this leaves `provinceName` empty when the payload
  /// omits it; [Province] re-attaches it when the district is placed inside a
  /// province, exactly as it does for the generated dataset.
  factory District.fromJson(Map<String, dynamic> json) => District(
        name: json['name'] as String,
        nameNe: json['nameNe'] as String?,
        nameNeVerified: json['nameNeVerified'] as bool? ?? false,
        cbsCode: json['cbsCode'] as int?,
        headquarter: json['headquarter'] as String?,
        areaSqKm: (json['areaSqKm'] as num?)?.toDouble(),
        website: json['website'] as String?,
        provinceName: json['province'] as String? ?? '',
        units: [
          for (final b in (json['localBodies'] as List? ?? const []))
            LocalBody.fromJson((b as Map).cast<String, dynamic>()),
        ],
      );

  /// Value equality over name and CBS code.
  @override
  bool operator ==(Object other) =>
      other is District && other.name == name && other.cbsCode == cbsCode;

  @override
  int get hashCode => Object.hash(name, cbsCode);

  @override
  String toString() => 'District($name)';
}

/// A province (7 nationwide).
class Province {
  /// Lowercase slug id, e.g. 'bagmati'.
  final String id;

  /// Display name, e.g. 'Bagmati'.
  final String name;

  /// Devanagari name, e.g. 'बागमती प्रदेश'. Present for all 7 provinces.
  final String? nameNe;

  /// Whether [nameNe] was corroborated by two independent sources.
  final bool nameNeVerified;

  /// CBS province code (1-7).
  final int cbsCode;

  /// The province's capital, e.g. 'Biratnagar' for Koshi.
  /// **Single-source** (sagautam5); present for all 7 provinces.
  final String? capital;

  /// Area in square kilometres. **Single-source** (sagautam5).
  final double? areaSqKm;

  /// The province's official website. **Single-source** (sagautam5).
  final String? website;

  /// ISO 3166-2 code (NP-P1..NP-P7).
  final String isoCode;

  /// Declared aggregate counts for this province.
  final ProvinceStats stats;

  /// Districts belonging to this province.
  final List<District> districts;

  Province({
    required this.id,
    required this.name,
    this.nameNe,
    this.nameNeVerified = false,
    required this.cbsCode,
    this.capital,
    this.areaSqKm,
    this.website,
    required this.isoCode,
    required this.stats,
    required this.districts,
  }) {
    for (final district in districts) {
      district.setProvinceContext(name);
    }
  }

  /// The Devanagari name when available, otherwise the English one.
  String get nameNeOrName => nameNe ?? name;

  /// Both scripts in one label, e.g. 'Bagmati · बागमती प्रदेश'.
  String get displayBoth => nameNe == null ? name : '$name · $nameNe';

  /// All local bodies in this province, flattened across districts.
  List<LocalBody> get localBodies => [
        for (final d in districts) ...d.localBodies,
      ];

  /// Total local bodies in this province.
  int get localBodyCount =>
      districts.fold<int>(0, (sum, d) => sum + d.localBodyCount);

  /// Ward total computed from the per-palika counts actually present in the
  /// data.
  ///
  /// Compare with [declaredWards]: the two differ wherever a palika has no
  /// verified ward count, because [declaredWards] comes from the published
  /// province total while this one only sums rows we can stand behind.
  int get verifiedWards =>
      localBodies.fold<int>(0, (sum, b) => sum + (b.wards ?? 0));

  /// The published ward total declared for this province.
  ///
  /// Lumbini reconciles exactly against [verifiedWards]; the other six differ
  /// by the wards of the palikas documented as roster defects in the
  /// CHANGELOG. Treat this as "the official figure" and [verifiedWards] as
  /// "the figure this package can substantiate".
  int get declaredWards => stats.wards;

  /// `declaredWards - verifiedWards`: wards accounted for by the official
  /// total but not substantiated by any row in this package. Zero when every
  /// palika's count reconciles.
  int get unreconciledWards => declaredWards - verifiedWards;

  /// Whether this province's declared total reconciles against its rows.
  bool get wardsReconcile => unreconciledWards == 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (nameNe != null) 'nameNe': nameNe,
        if (nameNeVerified) 'nameNeVerified': nameNeVerified,
        'cbsCode': cbsCode,
        if (capital != null) 'capital': capital,
        if (areaSqKm != null) 'areaSqKm': areaSqKm,
        if (website != null) 'website': website,
        'isoCode': isoCode,
        'stats': stats.toJson(),
        'districts': [for (final d in districts) d.toJson()],
      };

  /// Rebuilds a [Province] from [toJson] output. The constructor re-attaches
  /// each district's province context, so the result is fully wired.
  factory Province.fromJson(Map<String, dynamic> json) => Province(
        id: json['id'] as String,
        name: json['name'] as String,
        nameNe: json['nameNe'] as String?,
        nameNeVerified: json['nameNeVerified'] as bool? ?? false,
        cbsCode: json['cbsCode'] as int,
        capital: json['capital'] as String?,
        areaSqKm: (json['areaSqKm'] as num?)?.toDouble(),
        website: json['website'] as String?,
        isoCode: json['isoCode'] as String,
        stats: const ProvinceStats(
          districts: 0,
          metro: 0,
          subMetro: 0,
          mun: 0,
          ruralMun: 0,
          total: 0,
          wards: 0,
        ),
        districts: [
          for (final d in (json['districts'] as List? ?? const []))
            District.fromJson((d as Map).cast<String, dynamic>()),
        ],
      );

  /// Value equality over id and CBS code.
  @override
  bool operator ==(Object other) =>
      other is Province && other.id == id && other.cbsCode == cbsCode;

  @override
  int get hashCode => Object.hash(id, cbsCode);

  @override
  String toString() => 'Province($name)';
}

/// Computed national totals (matches the official federal structure).
class NationalStats {
  /// Provinces (7).
  final int provinces;

  /// Districts (77).
  final int districts;

  /// Metropolitan cities (6).
  final int metro;

  /// Sub-metropolitan cities (11).
  final int subMetro;

  /// Municipalities (276).
  final int municipalities;

  /// Rural municipalities (460).
  final int ruralMunicipalities;

  /// Total local bodies (753).
  final int total;

  /// The **declared** national ward total (6,743) — the figure published for
  /// Nepal's federal structure.
  ///
  /// This is NOT the sum of the per-palika ward counts in this package: the
  /// palikas with no verified count contribute 0 to that sum, so the two
  /// differ by [unreconciledWards]. Use [verifiedWards] when you need a total
  /// you can trace to actual rows; use this when you need the official figure.
  final int wards;

  /// Wards summed from the per-palika counts this package actually carries
  /// (6,697 as of v2.4.0).
  final int verifiedWards;

  /// How many palikas have no verified ward count (8 as of v2.4.0).
  final int wardGaps;

  /// `wards - verifiedWards`: the 46 wards claimed by the declared national
  /// total but not substantiated by any row here.
  int get unreconciledWards => wards - verifiedWards;

  const NationalStats({
    required this.provinces,
    required this.districts,
    required this.metro,
    required this.subMetro,
    required this.municipalities,
    required this.ruralMunicipalities,
    required this.total,
    required this.wards,
    this.verifiedWards = 0,
    this.wardGaps = 0,
  });

  /// Serializes the computed totals.

  Map<String, dynamic> toJson() => <String, dynamic>{
        'provinces': provinces,
        'districts': districts,
        'metro': metro,
        'subMetro': subMetro,
        'municipalities': municipalities,
        'ruralMunicipalities': ruralMunicipalities,
        'total': total,
        'wards': wards,
        'verifiedWards': verifiedWards,
        'wardGaps': wardGaps,
        'unreconciledWards': unreconciledWards,
      };

  @override
  String toString() => 'NationalStats(7 provinces, 77 districts, 753 local '
      'bodies, $wards declared wards, $verifiedWards verified)';
}

/// Typed result of [NepalAdminApi.search].
class SearchResult {
  /// Matching provinces.
  final List<Province> provinces;

  /// Matching districts.
  final List<District> districts;

  /// Matching local bodies.
  final List<LocalBody> localBodies;

  const SearchResult({
    this.provinces = const [],
    this.districts = const [],
    this.localBodies = const [],
  });

  bool get isEmpty =>
      provinces.isEmpty && districts.isEmpty && localBodies.isEmpty;

  int get length => provinces.length + districts.length + localBodies.length;
}

/// The main entry point for querying Nepal's administrative divisions.
class NepalAdminApi {
  // Private constructor exists only to prevent instantiation; it can never
  // execute, so it is excluded from the coverage floor (see tool/).
  // The marker must trail the code line itself, bare at line end: both this
  // tool and the coverage package only recognize that exact shape.
  NepalAdminApi._(); // coverage:ignore-line

  /// All 7 provinces.
  static List<Province> getAllProvinces() => NepalData.provinces.toList();

  /// A province by id, e.g. 'bagmati' (case-insensitive).
  ///
  /// Also matches ISO 3166-2 codes, e.g. 'NP-P3' (case-insensitive),
  /// so callers can use either identifier.
  static Province? getProvinceById(String id) {
    final lower = id.toLowerCase();
    final upper = id.toUpperCase();
    for (final p in NepalData.provinces) {
      if (p.id == lower || p.isoCode.toUpperCase() == upper) return p;
    }
    return null;
  }

  /// A province by ISO 3166-2 code, e.g. 'NP-P3' (case-insensitive).
  static Province? getProvinceByIso(String isoCode) {
    final upper = isoCode.toUpperCase();
    for (final p in NepalData.provinces) {
      if (p.isoCode.toUpperCase() == upper) return p;
    }
    return null;
  }

  /// A province by CBS code (1–7), e.g. `3` for Bagmati.
  static Province? getProvinceByCbs(int cbsCode) {
    for (final p in NepalData.provinces) {
      if (p.cbsCode == cbsCode) return p;
    }
    return null;
  }

  /// All 77 districts, flattened.
  static List<District> getAllDistricts() => [
        for (final p in NepalData.provinces) ...p.districts,
      ];

  /// Districts of one province (empty if the id is unknown).
  ///
  /// Accepts either a province id ('bagmati') or ISO code ('NP-P3').
  static List<District> getDistrictsByProvince(String provinceId) =>
      getProvinceById(provinceId)?.districts.toList() ?? const <District>[];

  /// A single district by name (case-insensitive), e.g. 'Chitwan'.
  static District? getDistrictByName(String name) {
    final lower = name.toLowerCase();
    for (final d in getAllDistricts()) {
      if (d.name.toLowerCase() == lower) return d;
    }
    return null;
  }

  /// A single district by CBS 3-digit code, e.g. `306` for Kathmandu.
  static District? getDistrictByCbs(int cbsCode) {
    for (final d in getAllDistricts()) {
      if (d.cbsCode == cbsCode) return d;
    }
    return null;
  }

  /// All 753 local bodies, flattened.
  static List<LocalBody> getAllLocalBodies() => [
        for (final d in getAllDistricts()) ...d.localBodies,
      ];

  /// Local bodies of one district (empty if the district is unknown).
  static List<LocalBody> getLocalBodiesByDistrict(String districtName) =>
      getDistrictByName(districtName)?.localBodies.toList() ??
      const <LocalBody>[];

  /// Local bodies of one province (empty if the province is unknown).
  ///
  /// Accepts either a province id ('bagmati') or ISO code ('NP-P3').
  static List<LocalBody> getLocalBodiesByProvince(String provinceId) =>
      getProvinceById(provinceId)?.localBodies.toList() ?? const <LocalBody>[];

  /// Local bodies of one [type] nationwide.
  static List<LocalBody> getLocalBodiesByType(LocalBodyType type) => [
        for (final b in getAllLocalBodies())
          if (b.type == type) b,
      ];

  /// Only doubly-attested local bodies (548/753 as of v2.4.0).
  static List<LocalBody> getVerifiedLocalBodies() => [
        for (final b in getAllLocalBodies())
          if (b.cbsCodeVerified) b,
      ];

  /// National totals, computed live from the dataset.
  ///
  /// [NationalStats.wards] is the declared national figure; [NationalStats.verifiedWards]
  /// is what the per-palika rows in this package actually sum to. They differ
  /// by [NationalStats.unreconciledWards] — that difference is real, not a bug,
  /// and both numbers are exposed rather than one being silently chosen.
  static NationalStats getNationalStats() {
    final provinces = NepalData.provinces;
    final districts = getAllDistricts();
    final bodies = getAllLocalBodies();

    int count(LocalBodyType t) => bodies.where((b) => b.type == t).length;

    return NationalStats(
      provinces: provinces.length,
      districts: districts.length,
      metro: count(LocalBodyType.metropolitan),
      subMetro: count(LocalBodyType.subMetropolitan),
      municipalities: count(LocalBodyType.municipality),
      ruralMunicipalities: count(LocalBodyType.ruralMunicipality),
      total: bodies.length,
      wards: provinces.fold<int>(0, (sum, p) => sum + p.stats.wards),
      verifiedWards: bodies.fold<int>(0, (sum, b) => sum + (b.wards ?? 0)),
      wardGaps: bodies.where((b) => b.wards == null).length,
    );
  }

  /// Palikas carrying a CBS code of any confidence (744/753 as of v2.4.0).
  ///
  /// This is the set to use when building a code-keyed lookup to join against
  /// external government datasets. For the strictest reading use
  /// [getVerifiedLocalBodies] instead.
  static List<LocalBody> getLocalBodiesWithCode() => [
        for (final b in getAllLocalBodies())
          if (b.hasCbsCode) b,
      ];

  /// Palikas whose code rests on a single attestation from the CBS roster
  /// (196 as of v2.4.0).
  static List<LocalBody> getSingleSourceLocalBodies() => [
        for (final b in getAllLocalBodies())
          if (b.cbsCodeConfidence == CbsCodeConfidence.singleSource) b,
      ];

  /// Palikas with no defensible code at all (9 as of v2.4.0).
  ///
  /// These are documented ambiguities, never omissions — the code was left
  /// null rather than guessed.
  static List<LocalBody> getUncodedLocalBodies() => [
        for (final b in getAllLocalBodies())
          if (!b.hasCbsCode) b,
      ];

  /// A local body by name **within one district** (both case-insensitive).
  ///
  /// Local-body names are not unique nationwide, so prefer this over scanning
  /// [search] when you already know the district. Returns every match, which
  /// can be more than one only if the district itself holds duplicates.
  static List<LocalBody> getLocalBodiesByName(
    String name,
    String districtName,
  ) {
    final lower = name.toLowerCase();
    final district = getDistrictByName(districtName);
    if (district == null) return const <LocalBody>[];
    return [
      for (final b in district.localBodies)
        if (b.name.toLowerCase() == lower) b,
    ];
  }

  /// The single local body at a `fullPath`, e.g.
  /// `'Bharatpur, Chitwan, Bagmati'`. Matching ignores case and surrounding
  /// whitespace, and accepts any prefix order of the three components, so
  /// `'Bharatpur, Chitwan'` resolves too when unambiguous.
  ///
  /// Returns null when the path matches nothing or matches more than one body.
  static LocalBody? getLocalBodyByFullPath(String path) {
    final parts = path
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    final matches = getAllLocalBodies().where((b) {
      final haystack = [b.name, b.districtName, b.provinceName]
          .map((s) => s.toLowerCase())
          .toSet();
      return parts.every(haystack.contains);
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }

  /// A local body by CBS code, at any confidence.
  ///
  /// Returns null when the code is not attested for any palika. Unlike
  /// [getLocalBodyByCbsVerified] this also resolves the single-source tier,
  /// so it resolves 744 of 753 rather than 548.
  static LocalBody? getLocalBodyByCbs(int cbsCode) {
    for (final b in getAllLocalBodies()) {
      if (b.cbsCode == cbsCode) return b;
    }
    return null;
  }

  /// A local body by CBS code, restricted to the doubly-attested tier.
  ///
  /// Use this when the code must have two independent sources behind it.
  static LocalBody? getLocalBodyByCbsVerified(int cbsCode) {
    for (final b in getAllLocalBodies()) {
      if (b.cbsCode == cbsCode && b.cbsCodeVerified) return b;
    }
    return null;
  }

  /// Case-insensitive search across provinces, districts and local bodies.
  ///
  /// Matches **both scripts**: an English query finds English and Devanagari
  /// names and vice versa, so `search('Bharatpur')` and `search('भारतपुर')`
  /// return the same palika. Devanagari matching is substring-based, so a
  /// partial script fragment such as 'भारत' also matches.
  ///
  /// Local-body names are **not unique** nationwide — always use the
  /// [LocalBody.districtName] and [LocalBody.provinceName] of each match
  /// to disambiguate. Prefer [LocalBody.fullPath] for display.
  static SearchResult search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const SearchResult();

    final provinces = NepalData.provinces
        .where((p) =>
            p.name.toLowerCase().contains(term) ||
            (p.nameNe?.toLowerCase().contains(term) ?? false) ||
            p.isoCode.toLowerCase().contains(term))
        .toList();

    final districts = getAllDistricts()
        .where((d) =>
            d.name.toLowerCase().contains(term) ||
            (d.nameNe?.toLowerCase().contains(term) ?? false))
        .toList();

    final localBodies = getAllLocalBodies()
        .where((lb) =>
            lb.name.toLowerCase().contains(term) ||
            (lb.nameNe?.toLowerCase().contains(term) ?? false) ||
            lb.fullPath.toLowerCase().contains(term) ||
            lb.type.fullName.toLowerCase().contains(term))
        .toList();

    return SearchResult(
      provinces: provinces,
      districts: districts,
      localBodies: localBodies,
    );
  }
}

/// Fluent helpers for working with palika lists.
///
/// Mirrors the patterns used by popular geo packages (`sortedByName`,
/// `whereUrban`, …) so dropdowns and pickers stay one-liners.
extension LocalBodyListX on List<LocalBody> {
  /// Alphabetical by name (case-insensitive).
  List<LocalBody> get sortedByName => [
        ...this,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Alphabetical by `fullPath` (name, district, province).
  List<LocalBody> get sortedByFullPath => [
        ...this,
      ]..sort((a, b) =>
          a.fullPath.toLowerCase().compareTo(b.fullPath.toLowerCase()));

  /// Only urban bodies (metro + sub-metro + municipality).
  List<LocalBody> get whereUrban => [
        for (final b in this)
          if (b.isUrban) b
      ];

  /// Only rural municipalities.
  List<LocalBody> get whereRural => [
        for (final b in this)
          if (b.isRural) b
      ];

  /// Only CBS-verified bodies.
  List<LocalBody> get whereVerified => [
        for (final b in this)
          if (b.cbsCodeVerified) b,
      ];

  /// Only bodies of the given [type].
  List<LocalBody> ofType(LocalBodyType type) => [
        for (final b in this)
          if (b.type == type) b,
      ];

  /// Only bodies with map coordinates.
  List<LocalBody> get whereMapped => [
        for (final b in this)
          if (b.hasCoordinates) b,
      ];

  /// Only bodies with verified ward counts.
  List<LocalBody> get whereWardsVerified => [
        for (final b in this)
          if (b.wardsVerified) b,
      ];

  /// Only bodies carrying a CBS code of any confidence (744/753).
  ///
  /// The right filter when building a code-keyed map to join against
  /// government datasets.
  List<LocalBody> get whereCoded => [
        for (final b in this)
          if (b.hasCbsCode) b,
      ];

  /// Only bodies whose code is doubly-attested (548/753).
  List<LocalBody> get whereDoublyAttested => [
        for (final b in this)
          if (b.cbsCodeVerified) b,
      ];

  /// Only bodies whose code rests on a single attestation (196/753).
  List<LocalBody> get whereSingleSource => [
        for (final b in this)
          if (b.cbsCodeConfidence == CbsCodeConfidence.singleSource) b,
      ];

  /// Only bodies with no attested code (9/753).
  List<LocalBody> get whereUncoded => [
        for (final b in this)
          if (!b.hasCbsCode) b,
      ];

  /// Only bodies that are both mapped and coded — the subset usable for a
  /// joined map view.
  List<LocalBody> get whereCodeAndCoordinateMapped => [
        for (final b in this)
          if (b.isCodeAndCoordinateMapped) b,
      ];

  /// Total wards summed from the rows present (unverified rows contribute 0).
  int get totalWards => fold<int>(0, (sum, b) => sum + (b.wards ?? 0));

  /// A code-keyed map for joining against external datasets.
  ///
  /// Later entries overwrite earlier ones; the dataset is built so codes are
  /// unique, so this is a convenience rather than a lossy fold. Bodies with no
  /// attested code are skipped.
  Map<int, LocalBody> get byCbsCode => <int, LocalBody>{
        for (final b in this)
          if (b.cbsCode != null) b.cbsCode!: b,
      };
}
