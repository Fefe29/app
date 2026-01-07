/// Alarms management UI page.
/// See ARCHITECTURE_DOCS.md (section: alarms_page.dart).
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/regatta_timer_provider.dart';
import '../../providers/sleep_timer_provider.dart';
import '../../providers/anchor_alarm_provider.dart';
import '../../providers/other_alarms_provider.dart';
import 'package:kornog/common/providers/app_providers.dart';
import 'package:kornog/features/charts/providers/boat_position_provider.dart';
import 'package:kornog/common/services/position_formatter.dart';

// Responsive font helper: scale a base font size according to screen width
double rfs(BuildContext context, double base, {double min = 12.0, double max = 28.0}) {
	final w = MediaQuery.of(context).size.width;
	final scale = w / 360.0; // 360 is a reasonable baseline
	final size = base * scale;
	return size.clamp(min, max);
}

class AlarmsPage extends ConsumerStatefulWidget {
	const AlarmsPage({super.key});
	@override
	ConsumerState<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends ConsumerState<AlarmsPage> with SingleTickerProviderStateMixin {
	late TabController _tabController;

	@override
	void initState() {
		super.initState();
		_tabController = TabController(length: 4, vsync: this);
		print('[ALARMS] ✅ initState - TabBar architecture activée');
	}

	@override
	void dispose() {
		_tabController.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		print('[ALARMS] 🏗️ BUILD - TabBar rebuilding');
		return Column(
			children: [
				// TabBar horizontale en haut
				Container(
					color: Theme.of(context).colorScheme.surface,
					child: TabBar(
						controller: _tabController,
						isScrollable: false,
						labelColor: Theme.of(context).colorScheme.primary,
						unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
						indicatorColor: Theme.of(context).colorScheme.primary,
						tabs: const [
							Tab(text: 'Régate'),
							Tab(text: 'Sommeil'),
							Tab(text: 'Mouillage'),
							Tab(text: 'Autre'),
						],
					),
				),
				
				// TabBarView pour le contenu
				Expanded(
					child: TabBarView(
						controller: _tabController,
						physics: const NeverScrollableScrollPhysics(), // ✅ Clic obligatoire, pas de swipe
						children: [
							_RegattaTab(),
							_SleepTab(),
							_AnchorTab(),
							_OtherAlarmsTab(),
						],
					),
				),
			],
		);
	}
}

// ============================================================================
// ONGLET 1: RÉGATE
// ============================================================================

class _RegattaTab extends ConsumerStatefulWidget {
	const _RegattaTab();
	@override
	ConsumerState<_RegattaTab> createState() => _RegattaTabState();
}

class _RegattaTabState extends ConsumerState<_RegattaTab> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(regattaTimerProvider.notifier).tick();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

		@override
		Widget build(BuildContext context) {
			final state = ref.watch(regattaTimerProvider);
			String fmt(int s) {
				final m = (s ~/ 60).toString().padLeft(2, '0');
				final r = (s % 60).toString().padLeft(2, '0');
				return '$m:$r';
			}
			return Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					mainAxisSize: MainAxisSize.max,
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						DropdownButton<RegattaSequence>(
							value: state.sequence,
							onChanged: (seq) => seq == null ? null : ref.read(regattaTimerProvider.notifier).selectSequence(seq),
							items: [
				    for (final seq in RegattaSequence.predefined)
					    DropdownMenuItem(value: seq, child: Text(seq.name, style: TextStyle(fontSize: rfs(context, 18)))),
							],
						),
						const SizedBox(height: 12),
									Expanded(
										child: Center(
											child: FittedBox(
												fit: BoxFit.scaleDown,
												alignment: Alignment.center,
												child: Text(
													fmt(state.remaining),
													style: Theme.of(context).textTheme.displayLarge?.copyWith(
														fontSize: 200,
														fontWeight: FontWeight.bold,
														color: Theme.of(context).colorScheme.primary,
														letterSpacing: 2,
													),
													textAlign: TextAlign.center,
												),
											),
										),
									),
						const SizedBox(height: 16),
						Wrap(spacing: 12, children: [
							ElevatedButton.icon(
								onPressed: state.running ? null : () => ref.read(regattaTimerProvider.notifier).start(),
								icon: const Icon(Icons.play_arrow),
								label: Text('Start', style: TextStyle(fontSize: rfs(context, 18))),
								style: ElevatedButton.styleFrom(
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							),
							ElevatedButton.icon(
								onPressed: state.running ? () => ref.read(regattaTimerProvider.notifier).stop() : null,
								icon: const Icon(Icons.pause),
								label: Text('Pause', style: TextStyle(fontSize: rfs(context, 18))),
								style: ElevatedButton.styleFrom(
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							),
							OutlinedButton.icon(
								onPressed: () => ref.read(regattaTimerProvider.notifier).reset(),
								icon: const Icon(Icons.restart_alt),
								label: Text('Reset', style: TextStyle(fontSize: rfs(context, 18))),
								style: OutlinedButton.styleFrom(
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							),
						]),
						const SizedBox(height: 16),
						Text('Repères: ' + state.sequence.marks.map((m) => fmt(m)).join(', '), style: TextStyle(fontSize: rfs(context, 16), fontWeight: FontWeight.w500)),
						const SizedBox(height: 8),
						LinearProgressIndicator(
							value: state.sequence.total == 0 ? 0 : (state.sequence.total - state.remaining) / state.sequence.total,
						),
					],
				),
			);
		}
}

// --- Sommeil ---
class _SleepTab extends ConsumerStatefulWidget {
	const _SleepTab();
	@override
	ConsumerState<_SleepTab> createState() => _SleepTabState();
}

class _SleepTabState extends ConsumerState<_SleepTab> {
	Timer? _timer;

	@override
	void initState() {
		super.initState();
		_timer = Timer.periodic(const Duration(seconds: 1), (_) {
			ref.read(sleepTimerProvider.notifier).tick();
			setState(() {});
		});
	}

	@override
	void dispose() {
		_timer?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final st = ref.watch(sleepTimerProvider);
		final notifier = ref.read(sleepTimerProvider.notifier);
		final remaining = notifier.remaining();
		String fmt(Duration d) => d.inMinutes.toString().padLeft(2, '0') + ':' + (d.inSeconds % 60).toString().padLeft(2, '0');
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Column(
				mainAxisSize: MainAxisSize.max,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(children: [
						Text('Durée sieste:', style: TextStyle(fontSize: rfs(context, 18), fontWeight: FontWeight.w500)),
						const SizedBox(width: 12),
						DropdownButton<int>(
							value: st.napDuration.inMinutes,
							onChanged: (v) => v == null ? null : notifier.setDuration(Duration(minutes: v)),
							items: const [10, 15, 20, 25, 30, 40, 45, 60]
								.map((m) => DropdownMenuItem(value: m, child: Text('$m min', style: TextStyle(fontSize: rfs(context, 16)))))
								.toList(),
						),
					]),
					const SizedBox(height: 24),
					if (st.running && st.wakeUpAt != null)
						Text('Réveil: ${st.wakeUpAt!.hour.toString().padLeft(2,'0')}:${st.wakeUpAt!.minute.toString().padLeft(2,'0')}', style: TextStyle(fontSize: rfs(context, 16), fontWeight: FontWeight.w500)),
					const SizedBox(height: 12),
								Expanded(
									child: Center(
										child: FittedBox(
											fit: BoxFit.scaleDown,
											alignment: Alignment.center,
											child: Text(
												st.running ? fmt(remaining) : fmt(st.napDuration),
												style: Theme.of(context).textTheme.displayLarge?.copyWith(
													fontSize: 200,
													fontWeight: FontWeight.bold,
													color: Theme.of(context).colorScheme.primary,
													letterSpacing: 2,
												),
												textAlign: TextAlign.center,
											),
										),
									),
								),
					const SizedBox(height: 24),
					Wrap(spacing: 12, children: [
						ElevatedButton.icon(
							onPressed: st.running ? null : () => notifier.start(),
							icon: const Icon(Icons.hotel),
							label: Text('Démarrer sieste', style: TextStyle(fontSize: rfs(context, 18))),
							style: ElevatedButton.styleFrom(
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
								padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
							),
						),
						if (st.alarmActive)
							ElevatedButton.icon(
								onPressed: () => notifier.stopAlarm(),
								icon: const Icon(Icons.stop_circle),
								label: Text('ARRÊTER ALARME', style: TextStyle(fontSize: rfs(context, 18), fontWeight: FontWeight.bold)),
								style: ElevatedButton.styleFrom(
									backgroundColor: Colors.red,
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							),
						if (!st.alarmActive)
							OutlinedButton.icon(
								onPressed: st.running ? () => notifier.cancel() : null,
								icon: const Icon(Icons.close),
								label: Text('Annuler', style: TextStyle(fontSize: rfs(context, 18))),
								style: OutlinedButton.styleFrom(
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							),
					]),
				],
			),
		);
	}
}

// --- Mouillage ---
class _AnchorTab extends ConsumerWidget {
	const _AnchorTab();
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final st = ref.watch(anchorAlarmProvider);
		final n = ref.read(anchorAlarmProvider.notifier);
		final boatPositionAsync = ref.watch(boatPositionProvider);

		return Padding(
			padding: const EdgeInsets.all(16),
			child: ListView(
				children: [
					SwitchListTile(
						title: Text('Alarme active', style: TextStyle(fontSize: rfs(context, 18), fontWeight: FontWeight.w500)),
						value: st.enabled,
						onChanged: (v) => n.toggle(v),
						subtitle: st.triggered ? Text('⚠️ Dérapage détecté', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: rfs(context, 16))) : null,
					),
					const SizedBox(height: 12),
					Text('Rayon: ${st.radiusMeters.toStringAsFixed(0)} m', style: TextStyle(fontSize: rfs(context, 16))),
					Slider(
						value: st.radiusMeters,
						min: 10,
						max: 200,
						divisions: 19,
						onChanged: (v) => n.setRadius(v),
					),
					const SizedBox(height: 12),
					boatPositionAsync.when(
						data: (boatPos) {
							if (boatPos == null) {
								return Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										ElevatedButton.icon(
											onPressed: null, // Désactivé
											icon: const Icon(Icons.my_location),
											label: Text('Position GPS indisponible', style: TextStyle(fontSize: rfs(context, 18))),
											style: ElevatedButton.styleFrom(
												shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
												padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
											),
										),
									],
								);
							}
							return ElevatedButton.icon(
								onPressed: () {
									print('📍 Définir position du mouillage: lat=${boatPos.latitude}, lon=${boatPos.longitude}');
									n.setAnchorPosition(boatPos.latitude, boatPos.longitude);								n.toggle(true);								},
								icon: const Icon(Icons.my_location),
								label: Text('Définir position actuelle', style: TextStyle(fontSize: rfs(context, 18))),
								style: ElevatedButton.styleFrom(
									shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
									padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
								),
							);
						},
						loading: () => const Center(child: CircularProgressIndicator()),
						error: (err, st) => Text('Erreur GPS: $err', style: const TextStyle(color: Colors.red)),
					),
					if (st.anchorLat != null)
						Padding(
							padding: const EdgeInsets.only(top: 12),
							child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('⚓ Position du mouillage:', style: TextStyle(fontSize: rfs(context, 16), fontWeight: FontWeight.bold)),
										const SizedBox(height: 8),
										Text(
											formatPosition(st.anchorLat!, st.anchorLon!),
											style: TextStyle(fontSize: rfs(context, 14), fontFamily: 'monospace'),
										),
									],
								),
						),
				],
			),
		);
	}
}

// --- Autre (depth + wind) ---
class _OtherAlarmsTab extends ConsumerWidget {
	const _OtherAlarmsTab();
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final st = ref.watch(otherAlarmsProvider);
		final n = ref.read(otherAlarmsProvider.notifier);
		return Padding(
			padding: const EdgeInsets.all(16),
			child: ListView(
				children: [
					Text('Profondeur', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
					SwitchListTile(
						title: const Text('Alarme profondeur faible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
						value: st.depth.enabled,
						onChanged: (v) => n.toggleDepth(v),
						subtitle: st.depth.triggered ? const Text('⚠️ Trop faible', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)) : null,
					),
					Row(children: [
						Expanded(
							child: Slider(
								value: st.depth.minDepthMeters.clamp(1, 100),
								min: 1,
								max: 50,
								divisions: 49,
								onChanged: st.depth.enabled ? (v) => n.setMinDepth(v) : null,
							),
						),
						SizedBox(width: 60, child: Text('${st.depth.minDepthMeters.toStringAsFixed(1)} m', style: const TextStyle(fontSize: 16))),
						if (st.depth.triggered)
							IconButton(
								tooltip: 'Réinitialiser',
								icon: const Icon(Icons.refresh),
								onPressed: n.resetDepthAlarm,
							),
					]),
					const Divider(height: 32),
					Text('Wind Shift', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
					SwitchListTile(
						title: const Text('Alarme shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
						value: st.windShift.enabled,
						onChanged: (v) => n.toggleWindShift(v),
						subtitle: st.windShift.triggered
							? Text('⚠️ Shift Δ=${st.windShift.currentDiffAbs?.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))
							: (st.windShift.currentDiffAbs != null ? Text('Δ=${st.windShift.currentDiffAbs!.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 16)) : null),
					),
					Row(children: [
						Expanded(
							child: Slider(
								value: st.windShift.thresholdDeg.clamp(2, 90),
								min: 2,
								max: 60,
								divisions: 58,
								onChanged: st.windShift.enabled ? (v) => n.setWindShiftThreshold(v) : null,
							),
						),
						SizedBox(width: 60, child: Text('${st.windShift.thresholdDeg.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 16))),
						IconButton(
							tooltip: 'Recalibrer',
							icon: const Icon(Icons.center_focus_strong),
							onPressed: st.windShift.enabled ? () {
								final dir = ref.read(metricProvider('wind.twd')).maybeWhen(data: (m) => m.value, orElse: () => null);
								if (dir != null) n.recalibrateShift(dir);
							} : null,
						),
						if (st.windShift.triggered)
							IconButton(
								tooltip: 'Reset',
								icon: const Icon(Icons.refresh),
								onPressed: n.resetShift,
							),
					]),
					const Divider(height: 32),
					Text('Wind Drop / Raise', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
					// Drop
					SwitchListTile(
						title: const Text('Alarme vent faible (Drop)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
						value: st.windDrop.enabled,
						onChanged: (v) => n.toggleWindDrop(v),
						subtitle: st.windDrop.triggered ? const Text('⚠️ Trop faible', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)) : null,
					),
					Row(children: [
						Expanded(
							child: Slider(
								value: st.windDrop.threshold.clamp(0, 40),
								min: 0,
								max: 30,
								divisions: 30,
								onChanged: st.windDrop.enabled ? (v) => n.setWindDropThreshold(v) : null,
							),
						),
						SizedBox(width: 60, child: Text('${st.windDrop.threshold.toStringAsFixed(1)} kn', style: const TextStyle(fontSize: 16))),
						if (st.windDrop.triggered)
							IconButton(icon: const Icon(Icons.refresh), onPressed: n.resetWindDrop),
					]),
					// Raise
					SwitchListTile(
						title: const Text('Alarme vent fort (Raise)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
						value: st.windRaise.enabled,
						onChanged: (v) => n.toggleWindRaise(v),
						subtitle: st.windRaise.triggered ? const Text('⚠️ Trop fort', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)) : null,
					),
					Row(children: [
						Expanded(
							child: Slider(
								value: st.windRaise.threshold.clamp(0, 60),
								min: 5,
								max: 50,
								divisions: 45,
								onChanged: st.windRaise.enabled ? (v) => n.setWindRaiseThreshold(v) : null,
							),
						),
						SizedBox(width: 60, child: Text('${st.windRaise.threshold.toStringAsFixed(1)} kn', style: const TextStyle(fontSize: 16))),
						if (st.windRaise.triggered)
							IconButton(icon: const Icon(Icons.refresh), onPressed: n.resetWindRaise),
					]),
				],
			),
		);
	}
}