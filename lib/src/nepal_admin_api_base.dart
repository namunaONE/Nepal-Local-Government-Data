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

/// Aggregate counts for one province.
class ProvinceStats {
  final int districts;
  final int metro;
  final int subMetro;
  final int mun;
  final int ruralMun;
  final int total;
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
  final String name;
  final LocalBodyType type;
  final String districtName;
  final String provinceName;

  /// CBS 5-digit code (PDDPP format: P=province 1-7, DD=district 01-77, PP=palika 01-99).
  /// Null if not verified against CBS/MoFAGA sources.
  final int? cbsCode;

  /// Whether the [cbsCode] is verified (doubly-attested by CBS + postal-2025).
  final bool cbsCodeVerified;

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

  const LocalBody({
    required this.name,
    required this.type,
    required this.districtName,
    required this.provinceName,
    this.cbsCode,
    this.cbsCodeVerified = false,
    this.lat,
    this.lng,
    this.geoSource,
    this.wards,
    this.wardsVerified = false,
  });

  /// Full display name of the type, e.g. 'Rural Municipality'.
  String get typeName => type.fullName;

  /// Whether this is an urban local government.
  bool get isUrban =>
      type == LocalBodyType.metropolitan ||
      type == LocalBodyType.subMetropolitan ||
      type == LocalBodyType.municipality;

  /// Whether this is a rural municipality.
  bool get isRural => type == LocalBodyType.ruralMunicipality;

  /// Whether approximate map coordinates are available.
  bool get hasCoordinates => lat != null && lng != null;

  /// Human-readable hierarchical path, e.g. 'Bharatpur, Chitwan, Bagmati'.
  /// Useful for dropdowns, breadcrumbs and disambiguating duplicate names.
  String get fullPath => '$name, $districtName, $provinceName';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type.shortName,
        'district': districtName,
        'province': provinceName,
        if (cbsCode != null) 'cbsCode': cbsCode,
        if (cbsCodeVerified) 'cbsCodeVerified': cbsCodeVerified,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (geoSource != null) 'geoSource': geoSource,
        if (wards != null) 'wards': wards,
        if (wardsVerified) 'wardsVerified': wardsVerified,
      };

  factory LocalBody.fromJson(Map<String, dynamic> json) => LocalBody(
        name: json['name'] as String,
        type: LocalBodyType.fromShort(json['type'] as String?),
        districtName: json['district'] as String? ?? '',
        provinceName: json['province'] as String? ?? '',
        cbsCode: json['cbsCode'] as int?,
        cbsCodeVerified: json['cbsCodeVerified'] as bool? ?? false,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        geoSource: json['geoSource'] as String?,
        wards: json['wards'] as int?,
        wardsVerified: json['wardsVerified'] as bool? ?? false,
      );

  @override
  String toString() => '$name (${type.shortName})';
}

/// A district (77 nationwide), owning its local bodies.
class District {
  final String name;

  /// CBS 3-digit district code (e.g., 101 for Taplejung, 306 for Kathmandu).
  /// First digit = province (1-7), next two = district within province.
  final int? cbsCode;
  final List<LocalBody> _units;
  String _provinceName;

  District({
    required this.name,
    this.cbsCode,
    required List<LocalBody> units,
    String provinceName = '',
  })  : _units = units,
        _provinceName = provinceName;

  /// Called by [Province] when this district is attached to it.
  // Public on purpose: the data lives in nepal_data.dart (another library).
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'province': _provinceName,
        if (cbsCode != null) 'cbsCode': cbsCode,
        'localBodies': [for (final b in _units) b.toJson()],
      };
}

/// A province (7 nationwide).
class Province {
  final String id;
  final String name;

  /// CBS province code (1-7).
  final int cbsCode;

  /// ISO 3166-2 code (NP-P1..NP-P7).
  final String isoCode;
  final ProvinceStats stats;
  final List<District> districts;

  Province({
    required this.id,
    required this.name,
    required this.cbsCode,
    required this.isoCode,
    required this.stats,
    required this.districts,
  }) {
    for (final district in districts) {
      district.setProvinceContext(name);
    }
  }

  /// All local bodies in this province, flattened across districts.
  List<LocalBody> get localBodies => [
        for (final d in districts) ...d.localBodies,
      ];

  /// Total local bodies in this province.
  int get localBodyCount =>
      districts.fold<int>(0, (sum, d) => sum + d.localBodyCount);
}

/// Computed national totals (matches the official federal structure).
class NationalStats {
  final int provinces;
  final int districts;
  final int metro;
  final int subMetro;
  final int municipalities;
  final int ruralMunicipalities;
  final int total;
  final int wards;

  const NationalStats({
    required this.provinces,
    required this.districts,
    required this.metro,
    required this.subMetro,
    required this.municipalities,
    required this.ruralMunicipalities,
    required this.total,
    required this.wards,
  });
}

/// Typed result of [NepalAdminApi.search].
class SearchResult {
  final List<Province> provinces;
  final List<District> districts;
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
  NepalAdminApi._(); // static-only class

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

  /// A single local body by CBS 5-digit code (PDDPP), e.g. `31304`
  /// (Bharatpur: district 313 Chitwan + palika 04).
  ///
  /// Returns null when no verified entry carries the code. Unverified
  /// entries (`cbsCode == null`) are never matched.
  static LocalBody? getLocalBodyByCbs(int cbsCode) {
    for (final b in getAllLocalBodies()) {
      if (b.cbsCode == cbsCode) return b;
    }
    return null;
  }

  /// Only CBS-verified local bodies (547/753 in v2.0.0).
  static List<LocalBody> getVerifiedLocalBodies() => [
        for (final b in getAllLocalBodies())
          if (b.cbsCodeVerified) b,
      ];

  /// National totals, computed live from the dataset.
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
    );
  }

  /// Case-insensitive search across provinces, districts and local bodies.
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
            p.isoCode.toLowerCase().contains(term))
        .toList();

    final districts = getAllDistricts()
        .where((d) => d.name.toLowerCase().contains(term))
        .toList();

    final localBodies = getAllLocalBodies()
        .where((lb) =>
            lb.name.toLowerCase().contains(term) ||
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
}
