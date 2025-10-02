/// Alarms management UI page.
/// See ARCHITECTURE_DOCS.md (section: alarms_page.dart).
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/regatta_timer_provider.dart';
import '../../providers/sleep_timer_provider.dart';
import '../../providers/anchor_alarm_provider.dart';
import '../../providers/other_alarms_provider.dart';
import 'package:kornog/common/providers/app_providers.dart';

class AlarmsPage extends ConsumerStatefulWidget {
	const AlarmsPage({super.key});
	@override
	ConsumerState<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends ConsumerState<AlarmsPage> with SingleTickerProviderStateMixin {
	late final TabController _tab;
	late final List<Tab> _tabs;

	@override
	void initState() {
		super.initState();
		_tabs = const [
			Tab(text: 'Régate'),
			Tab(text: 'Sommeil'),
			Tab(text: 'Mouillage'),
			Tab(text: 'Autre'),
		];
		_tab = TabController(length: _tabs.length, vsync: this);
	}

	@override
	void dispose() {
		_tab.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				Material(
					color: Theme.of(context).colorScheme.surface,
					child: TabBar(
						controller: _tab,
						tabs: _tabs,
						labelColor: Theme.of(context).colorScheme.primary,
					),
				),
				Expanded(
					child: TabBarView(
						controller: _tab,
						children: const [
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

// --- Régate ---
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
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					DropdownButton<RegattaSequence>(
						value: state.sequence,
						onChanged: (seq) => seq == null ? null : ref.read(regattaTimerProvider.notifier).selectSequence(seq),
						items: [
							for (final seq in RegattaSequence.predefined)
								DropdownMenuItem(value: seq, child: Text(seq.name)),
						],
					),
					const SizedBox(height: 12),
					Center(
						child: Text(
							fmt(state.remaining),
							style: Theme.of(context).textTheme.displayMedium,
						),
					),
					const SizedBox(height: 16),
					Wrap(spacing: 12, children: [
						ElevatedButton.icon(
							onPressed: state.running ? null : () => ref.read(regattaTimerProvider.notifier).start(),
							icon: const Icon(Icons.play_arrow),
							label: const Text('Start'),
						),
						ElevatedButton.icon(
							onPressed: state.running ? () => ref.read(regattaTimerProvider.notifier).stop() : null,
							icon: const Icon(Icons.pause),
							label: const Text('Pause'),
						),
						OutlinedButton.icon(
							onPressed: () => ref.read(regattaTimerProvider.notifier).reset(),
							icon: const Icon(Icons.restart_alt),
							label: const Text('Reset'),
						),
					]),
					const SizedBox(height: 16),
					Text('Repères: ' + state.sequence.marks.map((m) => fmt(m)).join(', ')),
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
class _SleepTab extends ConsumerWidget {
	const _SleepTab();
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final st = ref.watch(sleepTimerProvider);
		final notifier = ref.read(sleepTimerProvider.notifier);
		final remaining = notifier.remaining();
		String fmt(Duration d) => d.inMinutes.toString().padLeft(2, '0') + ':' + (d.inSeconds % 60).toString().padLeft(2, '0');
		return Padding(
			padding: const EdgeInsets.all(16),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(children: [
						const Text('Durée sieste:'),
						const SizedBox(width: 12),
						DropdownButton<int>(
							value: st.napDuration.inMinutes,
							onChanged: (v) => v == null ? null : notifier.setDuration(Duration(minutes: v)),
							items: const [10, 15, 20, 25, 30, 40, 45, 60]
									.map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
									.toList(),
						),
					]),
					const SizedBox(height: 24),
						if (st.running && st.wakeUpAt != null)
							Text('Réveil: ${st.wakeUpAt!.hour.toString().padLeft(2,'0')}:${st.wakeUpAt!.minute.toString().padLeft(2,'0')}'),
					const SizedBox(height: 12),
					Center(
						child: Text(
							st.running ? fmt(remaining) : fmt(st.napDuration),
							style: Theme.of(context).textTheme.displayMedium,
						),
					),
					const SizedBox(height: 24),
					Wrap(spacing: 12, children: [
						ElevatedButton.icon(
							onPressed: st.running ? null : () => notifier.start(),
							icon: const Icon(Icons.hotel),
							label: const Text('Démarrer sieste'),
						),
						OutlinedButton.icon(
							onPressed: st.running ? () => notifier.cancel() : null,
							icon: const Icon(Icons.close),
							label: const Text('Annuler'),
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
		return Padding(
			padding: const EdgeInsets.all(16),
			child: ListView(
				children: [
					SwitchListTile(
						title: const Text('Alarme active'),
						value: st.enabled,
						onChanged: (v) => n.toggle(v),
						subtitle: st.triggered ? const Text('⚠️ Dérapage détecté', style: TextStyle(color: Colors.red)) : null,
					),
					const SizedBox(height: 12),
					Text('Rayon: ${st.radiusMeters.toStringAsFixed(0)} m'),
					Slider(
						value: st.radiusMeters,
						min: 10,
						max: 200,
						divisions: 19,
						onChanged: (v) => n.setRadius(v),
					),
					const SizedBox(height: 12),
					ElevatedButton.icon(
						onPressed: () {
							// Placeholder: récupérer GPS réel ici
							n.setAnchorPosition(48.0, -4.5);
						},
						icon: const Icon(Icons.my_location),
						label: const Text('Définir position actuelle'),
					),
					if (st.anchorLat != null)
						Padding(
							padding: const EdgeInsets.only(top: 12),
							child: Text('Ancre: lat=${st.anchorLat}, lon=${st.anchorLon}'),
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
		Color warn(bool trig) => trig ? Colors.red : Theme.of(context).colorScheme.primary;
		return Padding(
			padding: const EdgeInsets.all(16),
			child: ListView(
				children: [
					Text('Profondeur', style: Theme.of(context).textTheme.titleMedium),
					SwitchListTile(
						title: const Text('Alarme profondeur faible'),
						value: st.depth.enabled,
						onChanged: (v) => n.toggleDepth(v),
						subtitle: st.depth.triggered ? const Text('⚠️ Trop faible', style: TextStyle(color: Colors.red)) : null,
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
						SizedBox(width: 60, child: Text('${st.depth.minDepthMeters.toStringAsFixed(1)} m')),
						if (st.depth.triggered)
							IconButton(
								tooltip: 'Réinitialiser',
								icon: const Icon(Icons.refresh),
								onPressed: n.resetDepthAlarm,
							),
					]),
					const Divider(height: 32),
					Text('Wind Shift', style: Theme.of(context).textTheme.titleMedium),
					SwitchListTile(
						title: const Text('Alarme shift'),
						value: st.windShift.enabled,
						onChanged: (v) => n.toggleWindShift(v),
						subtitle: st.windShift.triggered
							? Text('⚠️ Shift Δ=${st.windShift.currentDiffAbs?.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.red))
							: (st.windShift.currentDiffAbs != null ? Text('Δ=${st.windShift.currentDiffAbs!.toStringAsFixed(1)}°') : null),
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
						SizedBox(width: 60, child: Text('${st.windShift.thresholdDeg.toStringAsFixed(0)}°')),
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
					Text('Wind Drop / Raise', style: Theme.of(context).textTheme.titleMedium),
					// Drop
					SwitchListTile(
						title: const Text('Alarme vent faible (Drop)'),
						value: st.windDrop.enabled,
						onChanged: (v) => n.toggleWindDrop(v),
						subtitle: st.windDrop.triggered ? const Text('⚠️ Trop faible', style: TextStyle(color: Colors.red)) : null,
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
						SizedBox(width: 60, child: Text('${st.windDrop.threshold.toStringAsFixed(1)} kn')),
						if (st.windDrop.triggered)
							IconButton(icon: const Icon(Icons.refresh), onPressed: n.resetWindDrop),
					]),
					// Raise
					SwitchListTile(
						title: const Text('Alarme vent fort (Raise)'),
						value: st.windRaise.enabled,
						onChanged: (v) => n.toggleWindRaise(v),
						subtitle: st.windRaise.triggered ? const Text('⚠️ Trop fort', style: TextStyle(color: Colors.red)) : null,
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
						SizedBox(width: 60, child: Text('${st.windRaise.threshold.toStringAsFixed(1)} kn')),
						if (st.windRaise.triggered)
							IconButton(icon: const Icon(Icons.refresh), onPressed: n.resetWindRaise),
					]),
				],
			),
		);
	}
}