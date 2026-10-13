// A minimal address form: three dependent dropdowns over the offline dataset.
//
//   cd packages/nepal_admin_widgets/example
//   flutter run
//
// Everything here is static data compiled into the app — no network, no
// location permissions, no asset loading.
import 'package:flutter/material.dart';
import 'package:nepal_admin_api/nepal_admin_api.dart';
import 'package:nepal_admin_widgets/nepal_admin_widgets.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nepal address',
      theme: ThemeData(colorSchemeSeed: const Color(0xFFDC143C)),
      home: const AddressForm(),
    );
  }
}

class AddressForm extends StatefulWidget {
  const AddressForm({super.key});

  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final AdministrativeCascade _cascade = AdministrativeCascade();

  @override
  void dispose() {
    _cascade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _cascade.localBody;
    final stats = NepalAdminApi.getNationalStats();

    return Scaffold(
      appBar: AppBar(title: const Text('Nepal address')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${stats.provinces} provinces · ${stats.districts} districts · '
              '${stats.total} local bodies, offline',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            AdministrativeDropdown(
              cascade: _cascade,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            _Summary(body: body),
            if (body != null) ...[
              const Divider(height: 32),
              Text('Selected', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _Row('Name', body.name),
              _Row('Devanagari', body.nameNeOrName),
              _Row('Type', body.typeName),
              _Row('District', body.districtName),
              _Row('Province', body.provinceName),
              _Row(
                'CBS code',
                // Say which kind of claim this is rather than showing a bare
                // number: verified, single-source, or absent.
                body.cbsCode == null
                    ? 'not coded'
                    : '${body.cbsCodeString} '
                        '(${body.cbsCodeConfidence.wireName})',
              ),
              _Row('Wards', body.wards?.toString() ?? 'not recorded'),
              _Row(
                'Full path',
                body.fullPath,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.body});

  final LocalBody? body;

  @override
  Widget build(BuildContext context) {
    if (body == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Pick a province, then a district, then a local body.'),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(body!.type.shortName)),
        title: Text(body!.name),
        subtitle: Text(
          body!.nameNe != null ? body!.nameNe! : 'no Devanagari name attested',
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
