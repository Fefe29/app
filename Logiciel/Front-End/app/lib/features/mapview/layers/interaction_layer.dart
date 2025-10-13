import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class InteractionLayer extends StatelessWidget {
  const InteractionLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (signal) {
        // TODO: zoom sous molette -> provider zoom
      },
      onPointerDown: (_) {
        // TODO: début pan
      },
      onPointerMove: (_) {
        // TODO: panning -> provider centre
      },
      onPointerUp: (_) {},
      child: const SizedBox.expand(),
    );
  }
}
