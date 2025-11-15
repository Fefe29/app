# 📊 Integration Guide - Historical Session Data in Charts

**Date**: 15 novembre 2025  
**Goal**: Make charts display session data instead of real-time when a session is selected  
**Status**: 🚀 Ready for Implementation

---

## 🎯 The Problem

Currently:
- Charts always display **real-time data** from `telemetryBus`
- Even if you select a session, charts don't change
- No way to analyze historical sailing sessions

Goal:
- When session is selected → charts display **session data**
- When no session is selected → charts display **real-time data**

---

## 🔧 Implementation Steps

### Step 1: Modify Chart Widgets

**File**: `lib/features/analysis/presentation/widgets/single_wind_metric_chart.dart`

Replace the data loading logic to check for selected session:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Check if a session is selected
  final selectedSessionId = ref.watch(selectedSessionProvider);
  
  // Get the data provider based on data source
  final historyAsync = selectedSessionId != null
      ? _getSessionHistoryProvider(selectedSessionId, metricType).call(ref)  // NEW
      : _getHistoryProvider(metricType).call(ref);                           // EXISTING
  
  return Card(
    // ... rest of widget
  );
}

// NEW METHOD: Get provider for session data
static StateNotifierProvider Function(WidgetRef ref) _getSessionHistoryProvider(
  String sessionId,
  WindMetricType metricType,
) {
  return (ref) {
    final snapshotsAsync = ref.watch(sessionDataProvider(sessionId));
    return snapshotsAsync.whenData((snapshots) {
      // Extract metric from snapshots
      return snapshots.map((snapshot) {
        final value = _extractMetricValue(snapshot, metricType);
        return (
          ts: snapshot.ts,
          value: value,
        );
      }).toList();
    });
  };
}

// Helper to extract metric from snapshot
static double _extractMetricValue(
  TelemetrySnapshot snapshot,
  WindMetricType metricType,
) {
  return switch (metricType) {
    WindMetricType.twd => snapshot.metrics['wind.twd']?.value ?? 0.0,
    WindMetricType.twa => snapshot.metrics['wind.twa']?.value ?? 0.0,
    WindMetricType.tws => snapshot.metrics['wind.tws']?.value ?? 0.0,
  };
}
```

### Step 2: Add Header Indicator

Show which data source is being displayed:

```dart
Widget _buildHeader(BuildContext context, WidgetRef ref) {
  final config = _getMetricConfig(metricType);
  final selectedSessionId = ref.watch(selectedSessionProvider);  // NEW
  
  return Row(
    children: [
      Icon(config.icon, color: config.color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              selectedSessionId != null                           // NEW
                  ? '📊 Session: $selectedSessionId'
                  : '📡 En temps réel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selectedSessionId != null ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
      // ... refresh button
    ],
  );
}
```

### Step 3: Update Boat Speed Chart

**File**: `lib/features/analysis/presentation/pages/analysis_page.dart`

Same pattern for boat speed chart:

```dart
if (filters.boatSpeed) {
  final selectedSessionId = ref.watch(selectedSessionProvider);  // NEW
  
  if (selectedSessionId != null) {
    // Load from session
    final snapshotsAsync = ref.watch(sessionDataProvider(selectedSessionId));
    speedData = snapshotsAsync.whenData((snapshots) => snapshots
        .map((s) => (
          ts: s.ts,
          value: s.metrics['nav.sog']?.value ?? 0.0,
        ))
        .toList());
  } else {
    // Load real-time
    speedData = ref.watch(sogHistoryProvider);
  }
  
  return _buildBoatSpeedChart(speedData);
}
```

### Step 4: Clear Selection Button

Add way to go back to real-time:

```dart
// In SessionManagementWidget or analysis page header
if (selectedSessionId != null) {
  ElevatedButton.icon(
    icon: const Icon(Icons.clear),
    label: const Text('Retour en temps réel'),
    onPressed: () {
      ref.read(selectedSessionProvider.notifier).state = null;
      print('🔄 [Analysis] Retour aux données temps réel');
    },
  );
}
```

---

## 📊 Data Flow Diagram

### Before (Real-time only)
```
telemetryBus
    ↓
windHistoryService (accumulates)
    ↓
twdHistoryProvider
    ↓
Charts display
```

### After (Real-time + Historical)
```
selectedSessionProvider
    ↓
   null?
   / \
  /   \
YES   NO
|     |
|     sessionDataProvider(sessionId)
|     |
|     extract metric
|     |
|     Convert to [(ts, value)]
|     |
|     v
twdHistoryProvider
    |
    ↓
Charts display
```

---

## 🧪 Example: TWD (Wind Direction) Chart

### Current Code (Real-time)
```dart
// lib/features/analysis/domain/services/wind_history_service.dart
final twdHistoryProvider = StreamProvider<List<(DateTime ts, double value)>>((ref) {
  final service = ref.watch(windHistoryServiceProvider);
  return service.twdHistory.map((list) {
    return list.map((m) => (ts: m.ts, value: m.value)).toList();
  });
});
```

### New Code (Session + Real-time)
```dart
// Check if session selected
final selectedSessionId = ref.watch(selectedSessionProvider);

// Build provider dynamically
final twdHistoryAsync = selectedSessionId != null
    ? ref.watch(sessionDataProvider(selectedSessionId)).whenData((snapshots) {
        return snapshots.map((snapshot) {
          final twd = snapshot.metrics['wind.twd']?.value ?? 0.0;
          return (ts: snapshot.ts, value: twd);
        }).toList();
      })
    : ref.watch(twdHistoryProvider);

// Use twdHistoryAsync in chart
```

---

## 🔌 Providers Needed

### Already Exist ✅
- `selectedSessionProvider` - Which session is selected (NEW)
- `sessionDataProvider` - Load session data (EXISTING)
- `twdHistoryProvider` - Real-time TWD (EXISTING)
- `twaHistoryProvider` - Real-time TWA (EXISTING)
- `twsHistoryProvider` - Real-time TWS (EXISTING)

### Chart Widget Adaptation
- No new providers needed!
- Just change the data source conditionally

---

## 🚀 Implementation Order

1. **Step 1**: Update `single_wind_metric_chart.dart`
   - Add session check
   - Extract metric from session snapshots
   - Show data source indicator

2. **Step 2**: Update boat speed chart
   - Same pattern as wind charts
   - Extract `nav.sog` from session data

3. **Step 3**: Add "Clear Selection" button
   - Return to real-time data
   - In drawer or analysis page header

4. **Step 4**: Test!
   - Record a session
   - Open Gestion des sessions
   - Select session
   - Verify charts change

---

## 📋 Files to Modify

| File | Change | Complexity |
|------|--------|-----------|
| `single_wind_metric_chart.dart` | Add session data loading | Medium |
| `analysis_page.dart` | Add boat speed session support | Medium |
| `analysis_filter_drawer.dart` | Add "Clear selection" button | Low |

---

## 💡 Key Concepts

### Real-time Data (Current)
```dart
final historyAsync = ref.watch(twdHistoryProvider);
// Updates continuously as new data arrives
```

### Historical Data (New)
```dart
final sessionId = ref.watch(selectedSessionProvider);
final snapshotsAsync = ref.watch(sessionDataProvider(sessionId));
// All data is loaded at once from file
// No updates (snapshot is complete)
```

### Conditional Selection
```dart
final historyAsync = selectedSessionId != null
    ? snapshotsAsync.whenData((snapshots) => extractMetrics(snapshots))
    : ref.watch(twdHistoryProvider);
```

---

## 🎨 UI Indicators

### Real-time Mode
```
📡 En temps réel
(Charts update as data flows)
```

### Session Mode
```
📊 Session: session_1763197496013
(Charts show complete session data)
```

### Clear Selection
```
[Retour en temps réel] button
(Returns to real-time mode)
```

---

## ✅ Testing Checklist

- [ ] Start app, see real-time charts
- [ ] Open "Gestion des Sessions"
- [ ] Select a session
- [ ] Charts change to show session data
- [ ] Session ID shows in chart header
- [ ] Click "Retour en temps réel"
- [ ] Charts return to real-time
- [ ] Select different session
- [ ] Charts switch to new session data

---

## 🔗 Reference Providers

```dart
// To use in charts:
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/features/analysis/providers/analysis_filters.dart';

// Watch selected session
final selectedSessionId = ref.watch(selectedSessionProvider);

// Load session data
if (selectedSessionId != null) {
  final snapshotsAsync = ref.watch(sessionDataProvider(selectedSessionId));
  // Extract metrics from snapshots
}
```

---

**Status**: 🚀 READY TO IMPLEMENT  
**Estimated Effort**: 2-3 hours  
**Impact**: Complete session analysis system! 📊
