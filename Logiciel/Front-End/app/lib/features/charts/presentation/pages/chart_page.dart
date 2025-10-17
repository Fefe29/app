/// Chart page: integrates wind, course, polars.
/// See ARCHITECTURE_DOCS.md (section: chart_page.dart).
// ------------------------------
// File: lib/features/charts/presentation/pages/chart_page.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/providers.dart';
import '../widgets/course_canvas.dart';
import '../widgets/course_menu.dart';
import '../widgets/map_toolbar_button.dart';
import '../../providers/wind_trend_provider.dart';


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
		final wind = ref.watch(windSampleProvider);
		final course = ref.watch(courseProvider);
		final windTrend = ref.watch(windTrendSnapshotProvider);
		final route = ref.watch(routePlanProvider);
		
		// Conditions pour activer le bouton de routage
		// Maintenant on permet le routage même avec des données non fiables
		final canRoute = course.buoys.isNotEmpty;
		
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
					const SizedBox(width: 16),
					if (!route.isEmpty) ...[
						Icon(Icons.timer, size: 16, color: Colors.green.shade700),
						const SizedBox(width: 4),
						Text('Temps estimé: ${route.formattedTotalTime}', 
							style: TextStyle(
								color: Colors.green.shade700,
								fontWeight: FontWeight.w600,
							)),
						const SizedBox(width: 16),
					],
					ElevatedButton.icon(
						onPressed: canRoute ? () {
							print('CHART_PAGE - Bouton Nouveau routage appuyé');
							ref.read(routePlanProvider.notifier).reroute();
						} : null,
						icon: Icon(
							Icons.route, 
							size: 16,
							color: windTrend.isReliable ? null : Colors.orange,
						),
						label: Text(
							windTrend.isReliable 
								? 'Nouveau routage' 
								: 'Routage (données limitées)',
						),
						style: ElevatedButton.styleFrom(
							foregroundColor: canRoute 
								? (windTrend.isReliable ? null : Colors.orange)
								: Colors.grey,
						),
					),
					const Spacer(),
					const MapToolbarButton(),
					const SizedBox(width: 8),
// Importer button removed
				],
			),
		);
	}
}


// Removed placeholder time series chart; replaced by CourseCanvas.