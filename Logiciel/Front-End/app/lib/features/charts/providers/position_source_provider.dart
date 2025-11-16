import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Position source for telemetry/boat position selection.
/// Two sources supported: NMEA (from network) or DEVICE (local device GPS).
enum PositionSource { nmea, device }

class PositionSourceNotifier extends Notifier<PositionSource> {
	static const _prefsKey = 'kornog.position_source';

	@override
	PositionSource build() {
		// default value
		const defaultSource = PositionSource.nmea;

		// Load saved preference asynchronously; do not use `mounted` here.
		// If a saved value exists, update the state.
		Future.microtask(() async {
			try {
				final prefs = await SharedPreferences.getInstance();
				final raw = prefs.getString(_prefsKey);
				if (raw != null) {
					final match = PositionSource.values.firstWhere(
						(e) => e.toString() == raw,
						orElse: () => defaultSource,
					);
					// update state
					state = match;
				}
			} catch (_) {
				// ignore errors and keep default
			}
		});

		return defaultSource;
	}

	Future<void> setSource(PositionSource src) async {
		state = src;
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString(_prefsKey, src.toString());
		} catch (_) {
			// ignore write errors
		}
	}
}

final positionSourceProvider = NotifierProvider<PositionSourceNotifier, PositionSource>(
	PositionSourceNotifier.new,
);

