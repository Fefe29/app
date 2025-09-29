// ------------------------------
// File: lib/features/alarms/alarms_page.dart
// ------------------------------
import 'package:flutter/material.dart';


class AlarmsPage extends StatefulWidget {
const AlarmsPage({super.key});
@override
State<AlarmsPage> createState() => _AlarmsPageState();
}


class _AlarmsPageState extends State<AlarmsPage> {
bool anchorOn = false; double radius = 30;
@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
SwitchListTile(
title: const Text('Alarme de mouillage'),
value: anchorOn,
onChanged: (v) => setState(() => anchorOn = v),
),
const SizedBox(height: 12),
Text('Rayon: ${radius.toStringAsFixed(0)} m'),
Slider(value: radius, min: 10, max: 200, divisions: 19, onChanged: (v) => setState(() => radius = v)),
const SizedBox(height: 12),
ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.my_location), label: const Text('Définir position actuelle comme ancre')),
],
),
);
}
}