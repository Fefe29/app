import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/features/alarms/providers/regatta_timer_provider.dart';

void main() {
  runApp(const ProviderScope(child: TestApp()));
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '🎵 Sound Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TestPage(),
    );
  }
}

class TestPage extends ConsumerStatefulWidget {
  const TestPage({super.key});

  @override
  ConsumerState<TestPage> createState() => _TestPageState();
}

class _TestPageState extends ConsumerState<TestPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(regattaTimerProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('🎵 Sound Alarm Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Regatta Timer: ${state.remaining}s',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                ref.read(regattaTimerProvider.notifier).selectSequence(
                  const RegattaSequence('Test-10s', [10, 5, 0]),
                );
              },
              child: const Text('Select 10s sequence'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(regattaTimerProvider.notifier).start();
              },
              child: const Text('▶ START (hear LONG beep)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(regattaTimerProvider.notifier).stop();
              },
              child: const Text('⏸ STOP'),
            ),
            const SizedBox(height: 32),
            const Text(
              'ℹ️ Expected sounds:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• START: 🔔 LONG'),
            const Text('• 10-6s: 🔕🔕 DOUBLE SHORT'),
            const Text('• 5s: 🔕 SHORT (1x)'),
            const Text('• 4s: 🔕🔕 SHORT (2x)'),
            const Text('• 3s: 🔕🔕🔕 SHORT (3x)'),
            const Text('• 2s: 🔕🔕🔕🔕 SHORT (4x)'),
            const Text('• 1s: 🔕🔕🔕🔕🔕 SHORT (5x)'),
            const Text('• 0s: 🔔 LONG'),
          ],
        ),
      ),
    );
  }
}
