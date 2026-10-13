import 'package:flutter/foundation.dart';
import 'package:nepal_admin_api/nepal_admin_api.dart';

/// The levels a user has actually chosen.
///
/// Every level is nullable because a cascade is only ever partially filled.
/// [isComplete] is the honest way to ask "do I have a usable answer".
@immutable
class AdministrativeSelection {
  const AdministrativeSelection({
    this.province,
    this.district,
    this.localBody,
  });

  final Province? province;
  final District? district;
  final LocalBody? localBody;

  /// True when a local body — the unit people actually mean — is selected.
  bool get isComplete => localBody != null;

  /// True when nothing at all is selected.
  bool get isEmpty => province == null && district == null && localBody == null;

  @override
  bool operator ==(Object other) =>
      other is AdministrativeSelection &&
      other.province?.id == province?.id &&
      other.district?.name == district?.name &&
      other.localBody?.name == localBody?.name &&
      other.localBody?.districtName == localBody?.districtName;

  @override
  int get hashCode => Object.hash(
        province?.id,
        district?.name,
        localBody?.name,
        localBody?.districtName,
      );

  @override
  String toString() => localBody != null
      ? 'AdministrativeSelection(${localBody!.fullPath})'
      : 'AdministrativeSelection(province: ${province?.name}, '
          'district: ${district?.name})';
}

/// Which script(s) a label uses.
enum LabelStyle {
  /// English name only.
  english,

  /// Devanagari name only, falling back to English where none is attested.
  devanagari,

  /// Both scripts separated by ` · `. Falls back to whichever single script is
  /// attested, so a label never ends in a dangling separator.
  both,
}

/// Drives a province -> district -> local body cascade.
///
/// Deliberately widget-free. This holds the state transitions and the label
/// rules — the part actually worth testing — so it can be unit-tested directly
/// and driven by any UI. [AdministrativeDropdown] is one consumer.
///
/// ### Why the cascade rules are what they are
///
/// Local-body names are **not unique** nationwide: `Sunkoshi` names four
/// different rural municipalities. So a body is never resolved on its name
/// alone; the district is part of the answer, always. That drives two rules:
///
///  * Choosing a province clears the district and body beneath it.
///  * Choosing a district clears the body beneath it.
///
/// A stale child can never outlive the parent that made it meaningful.
class AdministrativeCascade extends ChangeNotifier {
  /// A cascade over the whole of Nepal.
  AdministrativeCascade()
      : provinces = NepalAdminApi.getAllProvinces(),
        districts = NepalAdminApi.getAllDistricts(),
        localBodies = NepalAdminApi.getAllLocalBodies();

  /// A cascade scoped to one province. Useful for regional forms, and it keeps
  /// the district list honest rather than merely filtered.
  AdministrativeCascade.forProvince(Province province)
      : provinces = [province],
        districts = NepalAdminApi.getDistrictsByProvince(province.id),
        localBodies = NepalAdminApi.getLocalBodiesByProvince(province.id);

  /// A cascade over a caller-supplied subset. For tests and for apps that
  /// already hold their own rosters.
  AdministrativeCascade.subset({
    required this.provinces,
    required this.districts,
    required this.localBodies,
  });

  /// The provinces offered, already sorted.
  final List<Province> provinces;
  final List<District> districts;
  final List<LocalBody> localBodies;

  Province? _province;
  District? _district;
  LocalBody? _localBody;

  Province? get province => _province;
  District? get district => _district;
  LocalBody? get localBody => _localBody;

  AdministrativeSelection get selection => AdministrativeSelection(
        province: _province,
        district: _district,
        localBody: _localBody,
      );

  /// District name -> district, for Devanagari labels and reverse lookups.
  late final Map<String, District> _districtByName = {
    for (final d in districts) d.name: d,
  };

  /// Districts available given the chosen province.
  List<District> get availableDistricts {
    final source = _province == null
        ? districts
        : districts.where((d) => d.provinceName == _province!.name);
    final list = source.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Local bodies available given the chosen province and district.
  ///
  /// Empty unless a province or district is chosen. Showing all 753 in one
  /// dropdown would push the district out of the answer and reintroduce the
  /// ambiguity the cascade exists to remove.
  List<LocalBody> get availableLocalBodies {
    final List<LocalBody> source;
    if (_district != null) {
      source =
          localBodies.where((b) => b.districtName == _district!.name).toList();
    } else if (_province != null) {
      source =
          localBodies.where((b) => b.provinceName == _province!.name).toList();
    } else {
      return const [];
    }
    return source.sortedByFullPath;
  }

  /// Selects a province, clearing the district and body beneath it.
  void selectProvince(Province? value) {
    if (identical(_province, value)) return;
    _province = value;
    _district = null;
    _localBody = null;
    notifyListeners();
  }

  /// Selects a district, clearing the body beneath it.
  void selectDistrict(District? value) {
    if (identical(_district, value)) return;
    _district = value;
    _localBody = null;
    // Keep the province coherent: a district chosen without one implies its
    // province, and a district from another province invalidates the old one.
    if (value != null) {
      _province = provinces.firstWhere(
        (p) => p.name == value.provinceName,
        orElse: () => _province ?? provinces.first,
      );
    }
    notifyListeners();
  }

  /// Selects a local body.
  ///
  /// Authoritative: the body carries its own district and province, so the
  /// upper levels are reconciled to match it. This is what makes it safe for a
  /// search result from anywhere in Nepal to select the whole chain — a body
  /// can never end up selected under a district it does not belong to.
  void selectLocalBody(LocalBody? value) {
    if (identical(_localBody, value)) return;
    _localBody = value;
    if (value != null) {
      _district ??= _districtByName[value.districtName];
      _province = provinces.firstWhere(
        (p) => p.name == value.provinceName,
        orElse: () => _province ?? provinces.first,
      );
      if (_province != null && _district != null) {
        _district = _province!.districts.firstWhere(
          (d) => d.name == value.districtName,
          orElse: () => _district!,
        );
      }
    }
    notifyListeners();
  }

  /// Sets the whole selection at once, e.g. restoring a saved address.
  ///
  /// Each level that is supplied overrides; levels left null are preserved.
  void selectAll({
    Province? province,
    District? district,
    LocalBody? localBody,
  }) {
    if (province != null) _province = province;
    if (district != null) _district = district;
    if (localBody != null) _localBody = localBody;
    // Reconcile downward: a body that survives a district change is no longer
    // a child of it.
    if (_localBody != null && _district != null) {
      if (_localBody!.districtName != _district!.name) _localBody = null;
    }
    notifyListeners();
  }

  /// Clears everything.
  void clear() {
    if (_province == null && _district == null && _localBody == null) return;
    _province = null;
    _district = null;
    _localBody = null;
    notifyListeners();
  }

  bool get isEmpty =>
      _province == null && _district == null && _localBody == null;

  // ---- label rules ------------------------------------------------------

  /// How to render a local body's name.
  static String formatLocalBody(
    LocalBody body, {
    LabelStyle style = LabelStyle.both,
  }) =>
      _format(
        english: body.name,
        devanagari: body.nameNe,
        style: style,
      );

  /// How to render a district's name.
  static String formatDistrict(
    District district, {
    LabelStyle style = LabelStyle.both,
  }) =>
      _format(
        english: district.name,
        devanagari: district.nameNe,
        style: style,
      );

  /// How to render a province's name.
  static String formatProvince(
    Province province, {
    LabelStyle style = LabelStyle.both,
  }) =>
      _format(
        english: province.name,
        devanagari: province.nameNe,
        style: style,
      );

  /// A label that is unique across Nepal, for lists spanning several districts.
  ///
  /// Bare local-body names are ambiguous, so anywhere more than one district is
  /// on screen the district must be in the label.
  static String formatLocalBodyDisambiguated(
    LocalBody body, {
    LabelStyle style = LabelStyle.both,
  }) =>
      '${formatLocalBody(body, style: style)}, ${body.districtName}';

  static String _format({
    required String english,
    required String? devanagari,
    required LabelStyle style,
  }) {
    switch (style) {
      case LabelStyle.english:
        return english;
      case LabelStyle.devanagari:
        return devanagari ?? english;
      case LabelStyle.both:
        return devanagari == null ? english : '$english · $devanagari';
    }
  }

  // ---- search -----------------------------------------------------------

  /// Free-text search over local bodies, matching either script.
  ///
  /// Narrowed by the current province and district when they are set, so every
  /// result is one the cascade could actually select. Empty [query] returns
  /// the available bodies unfiltered.
  ///
  /// Results are ranked exact, then prefix, then substring, then alphabetical:
  /// a user typing `kath` wants Kathmandu before Katunkhur.
  List<LocalBody> search(String query) {
    final term = query.trim().toLowerCase();
    final pool = availableLocalBodies;
    if (term.isEmpty) return pool;

    final hits = pool.where((b) {
      if (b.name.toLowerCase().contains(term)) return true;
      if ((b.nameNe ?? '').toLowerCase().contains(term)) return true;
      if (b.districtName.toLowerCase().contains(term)) return true;
      final dNe = _districtByName[b.districtName]?.nameNe;
      return (dNe ?? '').toLowerCase().contains(term);
    }).toList();

    int rank(LocalBody b) {
      final n = b.name.toLowerCase();
      final d = (b.nameNe ?? '').toLowerCase();
      if (n == term || d == term) return 0;
      if (n.startsWith(term) || d.startsWith(term)) return 1;
      if (n.contains(term) || d.contains(term)) return 2;
      return 3; // matched on the district name
    }

    hits.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return hits;
  }
}
