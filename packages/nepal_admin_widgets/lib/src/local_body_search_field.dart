import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:nepal_admin_widgets/nepal_admin_widgets.dart';

/// Search local bodies by name, in either script.
///
/// Results are labelled with their district, because bare local-body names are
/// not unique across Nepal. Choosing a result reconciles the cascade, so a
/// hit from a district the user had not yet chosen still selects the whole
/// province -> district -> body chain.
class LocalBodySearchField extends StatefulWidget {
  const LocalBodySearchField({
    super.key,
    required this.cascade,
    this.label = 'Search local bodies',
    this.labelStyle = LabelStyle.both,
    this.onSelected,
    this.maxResults = 20,
    this.debounce = const Duration(milliseconds: 200),
  });

  final AdministrativeCascade cascade;
  final String label;
  final LabelStyle labelStyle;
  final ValueChanged<LocalBody>? onSelected;

  /// Cap on rendered results. The cascade's own search is exhaustive; this
  /// only bounds what is painted.
  final int maxResults;

  final Duration debounce;

  @override
  State<LocalBodySearchField> createState() => _LocalBodySearchFieldState();
}

class _LocalBodySearchFieldState extends State<LocalBodySearchField> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;
  List<LocalBody> _results = const [];

  @override
  void initState() {
    super.initState();
    widget.cascade.addListener(_onCascadeChanged);
  }

  @override
  void didUpdateWidget(LocalBodySearchField old) {
    super.didUpdateWidget(old);
    if (!identical(old.cascade, widget.cascade)) {
      old.cascade.removeListener(_onCascadeChanged);
      widget.cascade.addListener(_onCascadeChanged);
      _search();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    widget.cascade.removeListener(_onCascadeChanged);
    super.dispose();
  }

  /// Re-scopes results when the cascade narrows underneath us, so results
  /// never outlive the district that made them valid.
  void _onCascadeChanged() => _search();

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, _search);
  }

  void _search() {
    if (!mounted) return;
    final term = _controller.text.trim();
    // A blank query means "not searching", not "show everything". The
    // cascade's search returns the whole available list for an empty term,
    // which would flood the field with arbitrary results the moment it is
    // cleared — including on first build.
    if (term.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final found = widget.cascade.search(term);
    setState(() => _results = found.take(widget.maxResults).toList());
  }

  void _clear() {
    _controller.clear();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                    onPressed: _clear,
                  ),
          ),
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final b = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(
                    AdministrativeCascade.formatLocalBody(
                      b,
                      style: widget.labelStyle,
                    ),
                  ),
                  subtitle: Text('${b.districtName}, ${b.provinceName}'),
                  onTap: () {
                    widget.onSelected?.call(b);
                    _clear();
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
