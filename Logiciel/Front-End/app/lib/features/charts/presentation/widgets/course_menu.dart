/// Contextual course interaction menu.
/// See ARCHITECTURE_DOCS.md (section: course_menu.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/course.dart';
import '../../providers/course_providers.dart';
import 'geographic_buoy_dialog.dart';
import 'geographic_line_dialog.dart';

enum _CourseAction {
  newBuoy,
  setStartLine,
  setFinishLine,
  modifications,
  clearCourse,
}

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
    await showDialog(
      context: context,
      builder: (context) => const GeographicBuoyDialog(role: BuoyRole.regular),
    );
  }

  Future<void> _openStartLineDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const GeographicLineDialog(
        lineType: LineType.start,
      ),
    );
  }

  Future<void> _openFinishLineDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const GeographicLineDialog(
        lineType: LineType.finish,
      ),
    );
  }

  Future<void> _openModificationsMenu(BuildContext context, WidgetRef ref, CourseState course) async {
    final items = <_ModificationItem>[];
    
    // Ajouter les bouées (exclure comité et viseur car gérées via ligne de départ)
    for (final buoy in course.buoys.where((b) => b.role == BuoyRole.regular)) {
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
        await showDialog(
          context: context,
          builder: (context) => GeographicBuoyDialog(role: item.buoy!.role, existing: item.buoy),
        );
        break;
      case _ModificationItemType.startLine:
        await showDialog(
          context: context,
          builder: (context) => GeographicLineDialog(
            lineType: LineType.start,
            existingLine: item.startLine,
          ),
        );
        break;
      case _ModificationItemType.finishLine:
        await showDialog(
          context: context,
          builder: (context) => GeographicLineDialog(
            lineType: LineType.finish,
            existingLine: item.finishLine,
          ),
        );
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
  subtitle: 'Lat: ${buoy.position.latitude.toStringAsFixed(5)}, Lon: ${buoy.position.longitude.toStringAsFixed(5)}',
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
      subtitle: 'Viseur: Lat: ${line.point1.latitude.toStringAsFixed(5)}, Lon: ${line.point1.longitude.toStringAsFixed(5)} - Comité: Lat: ${line.point2.latitude.toStringAsFixed(5)}, Lon: ${line.point2.longitude.toStringAsFixed(5)}',
      icon: Icons.flag,
      startLine: line,
    );
  }

  factory _ModificationItem.finishLine(LineSegment line) {
    return _ModificationItem._(
      type: _ModificationItemType.finishLine,
      title: 'Ligne d\'arrivée',
      subtitle: 'Marque 1: Lat: ${line.point1.latitude.toStringAsFixed(5)}, Lon: ${line.point1.longitude.toStringAsFixed(5)} - Marque 2: Lat: ${line.point2.latitude.toStringAsFixed(5)}, Lon: ${line.point2.longitude.toStringAsFixed(5)}',
      icon: Icons.sports_score,
      finishLine: line,
    );
  }
}
