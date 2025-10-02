/// Settings page (units/theme/etc.).
/// See ARCHITECTURE_DOCS.md (section: settings_page.dart).
// ------------------------------
// File: lib/features/settings/settings_page.dart
// ------------------------------
import 'package:flutter/material.dart';


class SettingsPage extends StatelessWidget {
const SettingsPage({super.key});


@override
Widget build(BuildContext context) {
return ListView(
padding: const EdgeInsets.all(16),
children: [
const Text('Sources de données', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
const SizedBox(height: 8),
Card(
child: ListTile(
leading: const Icon(Icons.wifi),
title: const Text('NMEA 0183 via UDP'),
subtitle: const Text('Port 10110'),
trailing: const Icon(Icons.chevron_right),
onTap: () {},
),
),
const SizedBox(height: 16),
const Text('App', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
SwitchListTile(
title: const Text('Thème sombre (système)'),
value: Theme.of(context).brightness == Brightness.dark,
onChanged: (_) {},
),
ListTile(
leading: const Icon(Icons.info_outline),
title: const Text('À propos'),
subtitle: const Text('Version 0.1.0'),
),
],
);
}
}