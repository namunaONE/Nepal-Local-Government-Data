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

  const LocalBody({
    required this.name,
    required this.type,
    required this.districtName,
    required this.provinceName,
    this.cbsCode,
    this.cbsCodeVerified = false,
  });

  /// Full display name of the type, e.g. 'Rural Municipality'.
  String get typeName => type.fullName;

  /// Whether this is an urban local government.
  bool get isUrban =>
      type == LocalBodyType.metropolitan ||
      type == LocalBodyType.subMetropolitan ||
      type == LocalBodyType.municipality;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type.shortName,
        'district': districtName,
        'province': provinceName,
        if (cbsCode != null) 'cbsCode': cbsCode,
        if (cbsCodeVerified) 'cbsCodeVerified': cbsCodeVerified,
      };

  factory LocalBody.fromJson(Map<String, dynamic> json) => LocalBody(
        name: json['name'] as String,
        type: LocalBodyType.fromShort(json['type'] as String?),
        districtName: json['district'] as String? ?? '',
        provinceName: json['province'] as String? ?? '',
        cbsCode: json['cbsCode'] as int?,
        cbsCodeVerified: json['cbsCodeVerified'] as bool? ?? false,
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
  static Province? getProvinceById(String id) {
    final lower = id.toLowerCase();
    for (final p in NepalData.provinces) {
      if (p.id == lower) return p;
    }
    return null;
  }

  /// All 77 districts, flattened.
  static List<District> getAllDistricts() => [
        for (final p in NepalData.provinces) ...p.districts,
      ];

  /// Districts of one province (empty if the id is unknown).
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

  /// All 753 local bodies, flattened.
  static List<LocalBody> getAllLocalBodies() => [
        for (final d in getAllDistricts()) ...d.localBodies,
      ];

  /// Local bodies of one district (empty if the district is unknown).
  static List<LocalBody> getLocalBodiesByDistrict(String districtName) =>
      getDistrictByName(districtName)?.localBodies.toList() ??
      const <LocalBody>[];

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
  /// to disambiguate.
  static SearchResult search(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return const SearchResult();

    final provinces = NepalData.provinces
        .where((p) => p.name.toLowerCase().contains(term))
        .toList();

    final districts = getAllDistricts()
        .where((d) => d.name.toLowerCase().contains(term))
        .toList();

    final localBodies = getAllLocalBodies()
        .where((lb) =>
            lb.name.toLowerCase().contains(term) ||
            lb.type.fullName.toLowerCase().contains(term))
        .toList();

    return SearchResult(
      provinces: provinces,
      districts: districts,
      localBodies: localBodies,
    );
  }
}
