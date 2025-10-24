import 'package:flutter/material.dart';
import '../../calculs/wind_ui_indicators.dart';

/// Widget Thermomètre de stabilité du vent
class WindStabilityThermometer extends StatelessWidget {
  final double? stdTwd;
  final double? stdTws;
  const WindStabilityThermometer({this.stdTwd, this.stdTws, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stdTwd != null) ...[
          Text('Stabilité: σ(TWD)=${stdTwd!.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold)),
          LinearProgressIndicator(
            value: (stdTwd! / 20).clamp(0.0, 1.0),
            backgroundColor: Colors.blue[50],
            color: Colors.blue,
            minHeight: 8,
          ),
        ],
        if (stdTws != null) ...[
          Text('Stabilité: σ(TWS)=${stdTws!.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.bold)),
          LinearProgressIndicator(
            value: (stdTws! / 5).clamp(0.0, 1.0),
            backgroundColor: Colors.green[50],
            color: Colors.green,
            minHeight: 8,
          ),
        ],
      ],
    );
  }
}

/// Widget Compas d’oscillation du vent
class WindOscillationCompassWidget extends StatelessWidget {
  final double amplitude;
  final double period;
  const WindOscillationCompassWidget({required this.amplitude, required this.period, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final compass = WindOscillationCompass(amplitude, period);
    return Row(
      children: [
        Icon(Icons.explore, color: Colors.orange),
        SizedBox(width: 8),
        Text(compass.label),
      ],
    );
  }
}
