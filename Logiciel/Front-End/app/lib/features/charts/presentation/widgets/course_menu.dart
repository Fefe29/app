/// Contextual course interaction menu.
/// See ARCHITECTURE_DOCS.md (section: course_menu.dart).
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
          case _CourseAction.newBuoy:
            await _openNewBuoyMenu(context, ref);
            break;
          case _CourseAction.setStartLine:
            await _openStartLineDialog(context, ref);
            break;
          case _CourseAction.setFinishLine:
            await _openFinishLineDialog(context, ref);
            break;
          case _CourseAction.modifications:
            await _openModificationsMenu(context, ref, course);
            break;
          case _CourseAction.clearCourse:
            await _confirmClearCourse(context, ref);
            break;
        }
      },
      itemBuilder: (c) => [
        const PopupMenuItem(value: _CourseAction.newBuoy, child: Text('Nouvelle marque')),
        const PopupMenuItem(value: _CourseAction.setStartLine, child: Text('Ligne de départ')),
        const PopupMenuItem(value: _CourseAction.setFinishLine, child: Text('Ligne d\'arrivée')),
        const PopupMenuItem(value: _CourseAction.modifications, child: Text('Modification')),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: course.buoys.isNotEmpty || course.startLine != null || course.finishLine != null,
          value: _CourseAction.clearCourse,
          child: const Text('Suppression parcours'),
        ),
      ],
    );
  }

  Future<void> _openNewBuoyMenu(BuildContext context, WidgetRef ref) async {
    final action = await showDialog<_BuoyType>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle marque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: const Text('Marque de parcours'),
              onTap: () => Navigator.of(ctx).pop(_BuoyType.regular),
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Comité'),
              onTap: () => Navigator.of(ctx).pop(_BuoyType.committee),
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Viseur'),
              onTap: () => Navigator.of(ctx).pop(_BuoyType.target),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
    
    if (action != null) {
      final role = switch (action) {
        _BuoyType.regular => BuoyRole.regular,
        _BuoyType.committee => BuoyRole.committee,
        _BuoyType.target => BuoyRole.target,
      };
      await _openBuoyDialog(context, ref, role: role);
    }
  }

  Future<void> _openStartLineDialog(BuildContext context, WidgetRef ref) async {
    final course = ref.read(courseProvider);
    final viseurBuoys = course.buoys.where((b) => b.role == BuoyRole.target).toList();
    final committeeBuoys = course.buoys.where((b) => b.role == BuoyRole.committee).toList();
    
    if (viseurBuoys.isEmpty || committeeBuoys.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Marques manquantes'),
          content: const Text('Vous devez créer au moins une bouée viseur et une bouée comité avant de définir la ligne de départ.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    
    Buoy? selectedViseur;
    Buoy? selectedCommittee;
    
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ligne de départ'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sélectionnez les marques pour la ligne de départ :'),
                const SizedBox(height: 16),
                DropdownButtonFormField<Buoy>(
                  decoration: const InputDecoration(
                    labelText: 'Position du viseur',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedViseur,
                  items: viseurBuoys.map((buoy) => DropdownMenuItem(
                    value: buoy,
                    child: Text('Viseur (${buoy.x.toStringAsFixed(1)}, ${buoy.y.toStringAsFixed(1)})'),
                  )).toList(),
                  onChanged: (buoy) => setState(() => selectedViseur = buoy),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Buoy>(
                  decoration: const InputDecoration(
                    labelText: 'Position du comité',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedCommittee,
                  items: committeeBuoys.map((buoy) => DropdownMenuItem(
                    value: buoy,
                    child: Text('Comité (${buoy.x.toStringAsFixed(1)}, ${buoy.y.toStringAsFixed(1)})'),
                  )).toList(),
                  onChanged: (buoy) => setState(() => selectedCommittee = buoy),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: selectedViseur != null && selectedCommittee != null ? () {
                ref.read(courseProvider.notifier).setStartLine(
                  selectedViseur!.x, selectedViseur!.y,
                  selectedCommittee!.x, selectedCommittee!.y,
                );
                Navigator.of(ctx).pop();
              } : null,
              child: const Text('Définir'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _openFinishLineDialog(BuildContext context, WidgetRef ref) async {
    final course = ref.read(courseProvider);
    final allBuoys = course.buoys.toList();
    
    if (allBuoys.length < 2) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Marques manquantes'),
          content: const Text('Vous devez créer au moins deux marques avant de définir la ligne d\'arrivée.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    
    Buoy? selectedMark1;
    Buoy? selectedMark2;
    
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ligne d\'arrivée'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sélectionnez les marques pour la ligne d\'arrivée :'),
                const SizedBox(height: 16),
                DropdownButtonFormField<Buoy>(
                  decoration: const InputDecoration(
                    labelText: 'Marque 1',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMark1,
                  items: allBuoys.map((buoy) => DropdownMenuItem(
                    value: buoy,
                    child: Text('${_labelFor(buoy)} (${buoy.x.toStringAsFixed(1)}, ${buoy.y.toStringAsFixed(1)})'),
                  )).toList(),
                  onChanged: (buoy) => setState(() => selectedMark1 = buoy),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Buoy>(
                  decoration: const InputDecoration(
                    labelText: 'Marque 2',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedMark2,
                  items: allBuoys.where((b) => b != selectedMark1).map((buoy) => DropdownMenuItem(
                    value: buoy,
                    child: Text('${_labelFor(buoy)} (${buoy.x.toStringAsFixed(1)}, ${buoy.y.toStringAsFixed(1)})'),
                  )).toList(),
                  onChanged: (buoy) => setState(() => selectedMark2 = buoy),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: selectedMark1 != null && selectedMark2 != null ? () {
                ref.read(courseProvider.notifier).setFinishLine(
                  selectedMark1!.x, selectedMark1!.y,
                  selectedMark2!.x, selectedMark2!.y,
                );
                Navigator.of(ctx).pop();
              } : null,
              child: const Text('Définir'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _openModificationsMenu(BuildContext context, WidgetRef ref, CourseState course) async {
    final items = <_ModificationItem>[];
    
    // Ajouter les bouées
    for (final buoy in course.buoys) {
      items.add(_ModificationItem.buoy(buoy));
    }
    
    // Ajouter la ligne de départ si elle existe
    if (course.startLine != null) {
      items.add(_ModificationItem.startLine(course.startLine!));
    }
    
    // Ajouter la ligne d'arrivée si elle existe
    if (course.finishLine != null) {
      items.add(_ModificationItem.finishLine(course.finishLine!));
    }
    
    if (items.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aucun élément'),
          content: const Text('Il n\'y a aucun élément à modifier dans le parcours.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    
    final selectedItem = await showDialog<_ModificationItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Éléments du parcours'),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                onTap: () => Navigator.of(ctx).pop(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
        ],
      ),
    );
    
    if (selectedItem != null) {
      await _openModificationActions(context, ref, selectedItem);
    }
  }

  Future<void> _openModificationActions(BuildContext context, WidgetRef ref, _ModificationItem item) async {
    final action = await showDialog<_ModificationAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: Text('Que voulez-vous faire avec ${item.title.toLowerCase()} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ModificationAction.edit),
            child: const Text('Modifier'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ModificationAction.delete),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (action == null) return;
    
    switch (action) {
      case _ModificationAction.edit:
        await _editItem(context, ref, item);
        break;
      case _ModificationAction.delete:
        await _deleteItem(context, ref, item);
        break;
    }
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref, _ModificationItem item) async {
    switch (item.type) {
      case _ModificationItemType.buoy:
        await _openBuoyDialog(context, ref, existing: item.buoy, role: item.buoy!.role);
        break;
      case _ModificationItemType.startLine:
        await _openStartLineEditDialog(context, ref, item.startLine!);
        break;
      case _ModificationItemType.finishLine:
        await _openFinishLineEditDialog(context, ref, item.finishLine!);
        break;
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, _ModificationItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer ${item.title.toLowerCase()} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final notifier = ref.read(courseProvider.notifier);
      switch (item.type) {
        case _ModificationItemType.buoy:
          notifier.removeBuoy(item.buoy!.id);
          break;
        case _ModificationItemType.startLine:
          notifier.removeStartLine();
          break;
        case _ModificationItemType.finishLine:
          notifier.removeFinishLine();
          break;
      }
    }
  }

  Future<void> _openStartLineEditDialog(BuildContext context, WidgetRef ref, LineSegment startLine) async {
    final x1 = TextEditingController(text: startLine.p1x.toString());
    final y1 = TextEditingController(text: startLine.p1y.toString());
    final x2 = TextEditingController(text: startLine.p2x.toString());
    final y2 = TextEditingController(text: startLine.p2y.toString());
    final formKey = GlobalKey<FormState>();
    
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier ligne de départ'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Position du viseur:'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _numField(label: 'X viseur', controller: x1)), 
                  const SizedBox(width: 8), 
                  Expanded(child: _numField(label: 'Y viseur', controller: y1))
                ]),
                const SizedBox(height: 16),
                const Text('Position du comité:'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _numField(label: 'X comité', controller: x2)), 
                  const SizedBox(width: 8), 
                  Expanded(child: _numField(label: 'Y comité', controller: y2))
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nx1 = double.parse(x1.text.replaceAll(',', '.'));
              final ny1 = double.parse(y1.text.replaceAll(',', '.'));
              final nx2 = double.parse(x2.text.replaceAll(',', '.'));
              final ny2 = double.parse(y2.text.replaceAll(',', '.'));
              ref.read(courseProvider.notifier).setStartLine(nx1, ny1, nx2, ny2);
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
  }

  Future<void> _openFinishLineEditDialog(BuildContext context, WidgetRef ref, LineSegment finishLine) async {
    final x1 = TextEditingController(text: finishLine.p1x.toString());
    final y1 = TextEditingController(text: finishLine.p1y.toString());
    final x2 = TextEditingController(text: finishLine.p2x.toString());
    final y2 = TextEditingController(text: finishLine.p2y.toString());
    final formKey = GlobalKey<FormState>();
    
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier ligne d\'arrivée'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Position marque 1:'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _numField(label: 'X1', controller: x1)), 
                  const SizedBox(width: 8), 
                  Expanded(child: _numField(label: 'Y1', controller: y1))
                ]),
                const SizedBox(height: 16),
                const Text('Position marque 2:'),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _numField(label: 'X2', controller: x2)), 
                  const SizedBox(width: 8), 
                  Expanded(child: _numField(label: 'Y2', controller: y2))
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final nx1 = double.parse(x1.text.replaceAll(',', '.'));
              final ny1 = double.parse(y1.text.replaceAll(',', '.'));
              final nx2 = double.parse(x2.text.replaceAll(',', '.'));
              final ny2 = double.parse(y2.text.replaceAll(',', '.'));
              ref.read(courseProvider.notifier).setFinishLine(nx1, ny1, nx2, ny2);
              Navigator.of(ctx).pop();
            },
            child: const Text('Enregistrer'),
          )
        ],
      ),
    );
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

  Future<void> _confirmClearCourse(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer le parcours'),
        content: const Text('Êtes-vous sûr de vouloir effacer tout le parcours (toutes les bouées et lignes) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(courseProvider.notifier).clear();
    }
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

enum _CourseAction { 
  newBuoy,
  setStartLine,
  setFinishLine,
  modifications,
  clearCourse
}

enum _BuoyType {
  regular,
  committee,
  target,
}

enum _ModificationItemType {
  buoy,
  startLine,
  finishLine,
}

enum _ModificationAction {
  edit,
  delete,
}

class _ModificationItem {
  final _ModificationItemType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Buoy? buoy;
  final LineSegment? startLine;
  final LineSegment? finishLine;

  _ModificationItem._({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.buoy,
    this.startLine,
    this.finishLine,
  });

  factory _ModificationItem.buoy(Buoy buoy) {
    final label = switch (buoy.role) {
      BuoyRole.committee => 'Comité',
      BuoyRole.target => 'Viseur',
      BuoyRole.regular => 'Bouée ${buoy.id}${buoy.passageOrder != null ? ' (P${buoy.passageOrder})' : ''}',
    };
    
    return _ModificationItem._(
      type: _ModificationItemType.buoy,
      title: label,
      subtitle: '(${buoy.x.toStringAsFixed(1)}, ${buoy.y.toStringAsFixed(1)})',
      icon: switch (buoy.role) {
        BuoyRole.committee => Icons.location_on,
        BuoyRole.target => Icons.visibility,
        BuoyRole.regular => Icons.radio_button_unchecked,
      },
      buoy: buoy,
    );
  }

  factory _ModificationItem.startLine(LineSegment line) {
    return _ModificationItem._(
      type: _ModificationItemType.startLine,
      title: 'Ligne de départ',
      subtitle: 'Viseur: (${line.p1x.toStringAsFixed(1)}, ${line.p1y.toStringAsFixed(1)}) - Comité: (${line.p2x.toStringAsFixed(1)}, ${line.p2y.toStringAsFixed(1)})',
      icon: Icons.flag,
      startLine: line,
    );
  }

  factory _ModificationItem.finishLine(LineSegment line) {
    return _ModificationItem._(
      type: _ModificationItemType.finishLine,
      title: 'Ligne d\'arrivée',
      subtitle: 'Marque 1: (${line.p1x.toStringAsFixed(1)}, ${line.p1y.toStringAsFixed(1)}) - Marque 2: (${line.p2x.toStringAsFixed(1)}, ${line.p2y.toStringAsFixed(1)})',
      icon: Icons.sports_score,
      finishLine: line,
    );
  }
}
