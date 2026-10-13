import 'package:flutter/material.dart';
import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:nepal_admin_widgets/nepal_admin_widgets.dart';

/// A cascading Province -> District -> Local body picker.
///
/// Three dependent dropdowns plus an optional search field, populated offline
/// from the [nepal_admin_api] dataset. Because local-body names are not unique
/// nationwide, the body list is always scoped to the chosen district: this
/// widget never asks the user to disambiguate by eye.
///
/// ```dart
/// final cascade = AdministrativeCascade();
/// cascade.addListener(() => setState(() {}));
///
/// AdministrativeDropdown(cascade: cascade);
///
/// if (cascade.selection.isComplete) save(cascade.localBody!.cbsCode);
/// ```
///
/// Pass a [cascade] to observe it from outside. Omit it and one is created
/// internally; read it back with [AdministrativeDropdown.cascadeOf].
class AdministrativeDropdown extends StatefulWidget {
  const AdministrativeDropdown({
    super.key,
    this.cascade,
    this.onChanged,
    this.provinceLabel = 'Province',
    this.districtLabel = 'District',
    this.localBodyLabel = 'Local body',
    this.labelStyle = LabelStyle.both,
    this.showSearch = true,
    this.searchPlaceholder = 'Search local bodies',
    this.spacing = 12,
  });

  /// The cascade to drive. One is created internally when omitted.
  final AdministrativeCascade? cascade;

  /// Called on every change. Check [AdministrativeSelection.isComplete] before
  /// treating it as an answer: choosing a province is not a finished selection.
  final ValueChanged<AdministrativeSelection>? onChanged;

  final String provinceLabel;
  final String districtLabel;
  final String localBodyLabel;

  /// Which script(s) the option labels use.
  final LabelStyle labelStyle;

  /// Show the search field above the local-body dropdown.
  final bool showSearch;
  final String searchPlaceholder;
  final double spacing;

  /// The cascade driving the nearest enclosing [AdministrativeDropdown].
  ///
  /// Throws a descriptive [FlutterError] if there is none, rather than
  /// returning null and pushing a null check onto every caller.
  static AdministrativeCascade cascadeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_CascadeScope>();
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No AdministrativeDropdown found in this context.'),
        ErrorDescription(
          'AdministrativeDropdown.cascadeOf was called on a context with no '
          'enclosing AdministrativeDropdown.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope.cascade;
  }

  @override
  State<AdministrativeDropdown> createState() => _AdministrativeDropdownState();
}

class _CascadeScope extends InheritedWidget {
  const _CascadeScope({required this.cascade, required super.child});

  final AdministrativeCascade cascade;

  @override
  bool updateShouldNotify(_CascadeScope old) =>
      !identical(old.cascade, cascade);
}

class _AdministrativeDropdownState extends State<AdministrativeDropdown> {
  AdministrativeCascade? _internal;

  AdministrativeCascade get _cascade =>
      widget.cascade ?? (_internal ??= AdministrativeCascade());

  @override
  void dispose() {
    // Only dispose what we created; a caller-supplied cascade is theirs.
    _internal?.dispose();
    super.dispose();
  }

  void _changed() {
    widget.onChanged?.call(_cascade.selection);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _cascade;
    return _CascadeScope(
      cascade: c,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => _buildBody(context, c),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdministrativeCascade c) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    final provinces = c.provinces.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final districts = c.availableDistricts;
    final bodies = c.availableLocalBodies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<Province>(
          key: ValueKey('province-${c.province?.id}'),
          initialValue: c.province,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.provinceLabel,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final p in provinces)
              DropdownMenuItem<Province>(
                value: p,
                child: Text(
                  AdministrativeCascade.formatProvince(p,
                      style: widget.labelStyle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            c.selectProvince(v);
            _changed();
          },
        ),
        SizedBox(height: widget.spacing),
        DropdownButtonFormField<District>(
          // DropdownButtonFormField reads initialValue once, on first build.
          // Keying on the scoped selection and set size forces a fresh field
          // whenever narrowing changes the option list, instead of leaving a
          // stale value that is no longer among `items`.
          key: ValueKey(
            'district-${c.province?.id}-${c.district?.name}-${districts.length}',
          ),
          initialValue: districts.any((d) => identical(d, c.district))
              ? c.district
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.districtLabel,
            border: const OutlineInputBorder(),
            helperText: c.province == null
                ? 'Choose a province first'
                : '${districts.length} available',
            helperStyle: c.province == null ? TextStyle(color: muted) : null,
          ),
          items: [
            for (final d in districts)
              DropdownMenuItem<District>(
                value: d,
                child: Text(
                  AdministrativeCascade.formatDistrict(d,
                      style: widget.labelStyle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: c.province == null
              ? null
              : (v) {
                  c.selectDistrict(v);
                  _changed();
                },
        ),
        if (widget.showSearch) ...[
          SizedBox(height: widget.spacing),
          LocalBodySearchField(
            cascade: c,
            label: widget.searchPlaceholder,
            labelStyle: widget.labelStyle,
            onSelected: (b) {
              c.selectLocalBody(b);
              _changed();
            },
          ),
        ],
        SizedBox(height: widget.spacing),
        DropdownButtonFormField<LocalBody>(
          key: ValueKey(
            'localbody-${c.district?.name}-${c.localBody?.name}-${bodies.length}',
          ),
          initialValue:
              bodies.any((b) => identical(b, c.localBody)) ? c.localBody : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.localBodyLabel,
            border: const OutlineInputBorder(),
            helperText: c.district == null
                ? 'Choose a district first'
                : '${bodies.length} in ${c.district!.name}',
            helperStyle: c.district == null ? TextStyle(color: muted) : null,
          ),
          items: [
            for (final b in bodies)
              DropdownMenuItem<LocalBody>(
                value: b,
                child: Text(
                  AdministrativeCascade.formatLocalBody(b,
                      style: widget.labelStyle),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: c.district == null
              ? null
              : (v) {
                  c.selectLocalBody(v);
                  _changed();
                },
        ),
      ],
    );
  }
}
