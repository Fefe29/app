import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/charts/providers/position_source_provider.dart';

/// Small widget allowing the user to choose the source of boat position:
/// - NMEA: position coming from the network / NMEA bus
/// - DEVICE: device GPS
///
/// This widget is intentionally standalone and does not modify any
/// existing Settings tab behaviour. To show it in the Network tab,
/// insert `const PositionSourceWidget()` where appropriate.
class PositionSourceWidget extends ConsumerWidget {
	const PositionSourceWidget({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final source = ref.watch(positionSourceProvider);

		return Card(
			margin: const EdgeInsets.symmetric(vertical: 8.0),
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text('Source de position', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
						const SizedBox(height: 8),
						RadioListTile<PositionSource>(
							value: PositionSource.nmea,
							groupValue: source,
							title: const Text('Réseau NMEA'),
							subtitle: const Text('Utiliser la position provenant du flux NMEA (miniplexe / réseau).'),
							onChanged: (v) {
								if (v != null) ref.read(positionSourceProvider.notifier).setSource(v);
							},
						),
						RadioListTile<PositionSource>(
							value: PositionSource.device,
							groupValue: source,
							title: const Text('GPS Appareil'),
							subtitle: const Text('Utiliser le GPS interne de l\'appareil.'),
							onChanged: (v) {
								if (v != null) ref.read(positionSourceProvider.notifier).setSource(v);
							},
						),
					],
				),
			),
		);
	}
}

