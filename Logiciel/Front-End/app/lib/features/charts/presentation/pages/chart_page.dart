// ------------------------------
// File: lib/features/charts/presentation/pages/chart_page.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import '../widgets/course_canvas.dart';
import '../widgets/course_menu.dart';


class ChartsPage extends ConsumerWidget {
	const ChartsPage({super.key});
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final polarAsync = ref.watch(polarTableProvider);
		return polarAsync.when(
			loading: () => const Center(child: CircularProgressIndicator()),
			error: (e, _) => Center(child: Text('Erreur chargement polaires: $e')),
			data: (table) {
				return Column(
					children: [
						_HeaderStatus(table: table),
						const Divider(height: 1),
						const Expanded(child: Padding(
							padding: EdgeInsets.all(8.0),
							child: CourseCanvas(),
						)),
					],
				);
			},
		);
	}
}

class _HeaderStatus extends ConsumerWidget {
	const _HeaderStatus({required this.table});
	final dynamic table;
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final wind = ref.watch(unifiedWindProvider);
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
			alignment: Alignment.centerLeft,
			child: Row(
				children: [
					const CourseMenuButton(),
					const SizedBox(width: 12),
					Icon(table == null ? Icons.cloud_off : Icons.sailing, size: 18),
					const SizedBox(width: 8),
					Text(table == null ? 'Aucune polaire' : 'Polaires: ${table.angleCount} angles'),
					const SizedBox(width: 16),
					Text('Vent: ${wind.directionDeg.toStringAsFixed(0)}° / ${wind.speed.toStringAsFixed(1)} nds'),
					const Spacer(),
					TextButton.icon(
						onPressed: () {
							// TODO: import fichier / asset
						},
						icon: const Icon(Icons.file_upload_outlined, size: 16),
						label: const Text('Importer'),
					)
				],
			),
		);
	}
}


// Removed placeholder time series chart; replaced by CourseCanvas.