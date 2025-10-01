import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/course_providers.dart';
import '../../domain/models/course.dart';

/// Menu déroulant permettant d'ajouter / modifier des bouées.
class CourseMenuButton extends ConsumerWidget {
  const CourseMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    return PopupMenuButton<_CourseAction>(
      tooltip: 'Parcours',
      icon: const Icon(Icons.room_preferences_outlined, size: 20),
      onSelected: (action) async {
        switch (action) {
          case _CourseAction.addRegular:
            await _openBuoyDialog(context, ref, role: BuoyRole.regular);
            break;
          case _CourseAction.addCommittee:
            await _openBuoyDialog(context, ref, role: BuoyRole.committee);
            break;
          case _CourseAction.addTarget:
            await _openBuoyDialog(context, ref, role: BuoyRole.target);
            break;
          case _CourseAction.editExisting:
            await _openEditSelector(context, ref, course);
            break;
        }
      },
      itemBuilder: (c) => [
        const PopupMenuItem(value: _CourseAction.addRegular, child: Text('Ajouter bouée parcours')),
        const PopupMenuItem(value: _CourseAction.addCommittee, child: Text('Ajouter bouée comité')),
        const PopupMenuItem(value: _CourseAction.addTarget, child: Text('Ajouter bouée viseur')),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: course.buoys.isNotEmpty,
            value: _CourseAction.editExisting,
            child: const Text('Modifier bouée existante')
        ),
      ],
    );
  }

  Future<void> _openEditSelector(BuildContext context, WidgetRef ref, CourseState course) async {
    final buoy = await showDialog<Buoy>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Sélectionner une bouée'),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: course.buoys.length,
              itemBuilder: (c, i) {
                final b = course.buoys[i];
                return ListTile(
                  title: Text(_labelFor(b)),
                  subtitle: Text('(${b.x.toStringAsFixed(1)}, ${b.y.toStringAsFixed(1)})'),
                  onTap: () => Navigator.of(ctx).pop(b),
                );
              },
            ),
          ),
        );
      },
    );
    if (buoy != null) {
      await _openBuoyDialog(context, ref, existing: buoy, role: buoy.role);
    }
  }

  Future<void> _openBuoyDialog(BuildContext context, WidgetRef ref, {required BuoyRole role, Buoy? existing}) async {
    final xCtrl = TextEditingController(text: existing?.x.toString() ?? '0');
    final yCtrl = TextEditingController(text: existing?.y.toString() ?? '0');
    final passageCtrl = TextEditingController(text: existing?.passageOrder?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? _titleForRole(role) : 'Modifier ${_titleForRole(role)}'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [Expanded(child: _numField(label: 'X', controller: xCtrl)), const SizedBox(width: 12), Expanded(child: _numField(label: 'Y', controller: yCtrl))]),
                  const SizedBox(height: 12),
                  if (role == BuoyRole.regular)
                    _numField(label: 'Passage #', controller: passageCtrl, requiredField: false),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final x = double.parse(xCtrl.text.replaceAll(',', '.'));
                final y = double.parse(yCtrl.text.replaceAll(',', '.'));
                final passage = passageCtrl.text.trim().isEmpty ? null : int.parse(passageCtrl.text.trim());
                final notifier = ref.read(courseProvider.notifier);
                if (existing == null) {
                  notifier.addBuoy(x, y, passageOrder: passage, role: role);
                } else {
                  notifier.updateBuoy(existing.id, x: x, y: y, passageOrder: passage, role: role);
                }
                Navigator.of(ctx).pop();
              },
              child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
            )
          ],
        );
      },
    );
  }

  String _titleForRole(BuoyRole role) {
    switch (role) {
      case BuoyRole.committee:
        return 'Bouée comité';
      case BuoyRole.target:
        return 'Bouée viseur';
      case BuoyRole.regular:
      default:
        return 'Bouée parcours';
    }
  }

  String _labelFor(Buoy b) {
    switch (b.role) {
      case BuoyRole.committee:
        return 'Comité';
      case BuoyRole.target:
        return 'Viseur';
      case BuoyRole.regular:
      default:
        final po = b.passageOrder != null ? ' (P${b.passageOrder})' : '';
        return 'B${b.id}$po';
    }
  }

  Widget _numField({required String label, required TextEditingController controller, bool requiredField = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      validator: (v) {
        final txt = v?.trim() ?? '';
        if (txt.isEmpty) {
          if (!requiredField) return null; // Peut être vide si facultatif
          return 'Requis';
        }
        final parsed = double.tryParse(txt.replaceAll(',', '.'));
        if (parsed == null) return 'Nombre invalide';
        return null;
      },
    );
  }
}

enum _CourseAction { addRegular, addCommittee, addTarget, editExisting }
