import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'uci_engine_service.dart';

/// Defines the exclusive owner of the underlying UCI engine process.
enum EngineLeaseType {
  none,
  analysis,
  play,
  hint,
}

/// Token representing an active exclusive lease.
class EngineLease {
  final EngineLeaseType type;
  final int leaseId;
  final DateTime? acquiredAt;

  const EngineLease({
    required this.type,
    required this.leaseId,
    this.acquiredAt,
  });

  static const EngineLease none = EngineLease(
    type: EngineLeaseType.none,
    leaseId: 0,
    acquiredAt: null,
  );

  @override
  String toString() => 'EngineLease(type: $type, id: $leaseId)';
}

/// Central arbiter ensuring exactly ONE consumer owns the engine process at any moment.
///
/// Analysis, Play, and Hint must acquire an exclusive lease through this coordinator.
/// Mutual exclusion guarantees that background analysis never collides with gameplay,
/// and that ephemeral hint searches safely pause and resume gameplay without duplicating
/// processes or thrashing the engine.
class EngineCoordinator extends ChangeNotifier {
  static final EngineCoordinator _instance = EngineCoordinator._internal();
  factory EngineCoordinator() => _instance;
  EngineCoordinator._internal();

  UciEngineService? _engineService;
  EngineLease _activeLease = EngineLease.none;
  int _nextLeaseId = 0;
  Completer<void>? _transitionLock;

  EngineLease get activeLease => _activeLease;
  EngineLeaseType get activeLeaseType => _activeLease.type;
  bool get hasActiveLease => _activeLease.type != EngineLeaseType.none;
  UciEngineService? get engineService => _engineService;

  void attachEngineService(UciEngineService service) {
    _engineService = service;
  }

  /// Acquires an exclusive lease of the given [type].
  ///
  /// If another lease is active:
  /// - Waits for current transition lock.
  /// - Stops any active search on the underlying engine service.
  /// - Grants the new lease and returns it.
  Future<EngineLease> acquireLease(EngineLeaseType type) async {
    while (_transitionLock != null) {
      await _transitionLock!.future;
    }

    if (_activeLease.type == type) {
      return _activeLease;
    }

    _transitionLock = Completer<void>();
    try {
      final oldLease = _activeLease;
      if (kDebugMode) {
        developer.log(
          'EngineCoordinator: Transitioning from $oldLease to $type',
          name: 'EngineCoordinator',
        );
      }

      // Safely halt existing engine search if one was active
      if (_engineService != null && _engineService!.isProcessAlive) {
        if (_engineService!.isAnalyzing) {
          _engineService!.stopAnalysis();
          await _engineService!.waitForStopCompletion();
        }
      }

      final leaseId = ++_nextLeaseId;
      _activeLease = EngineLease(
        type: type,
        leaseId: leaseId,
        acquiredAt: DateTime.now(),
      );

      notifyListeners();
      return _activeLease;
    } finally {
      final lock = _transitionLock;
      _transitionLock = null;
      if (lock != null && !lock.isCompleted) {
        lock.complete();
      }
    }
  }

  /// Releases the lease held by [lease].
  Future<void> releaseLease(EngineLease lease) async {
    while (_transitionLock != null) {
      await _transitionLock!.future;
    }

    if (_activeLease.leaseId != lease.leaseId) {
      return; // Stale or already released
    }

    _transitionLock = Completer<void>();
    try {
      if (_engineService != null && _engineService!.isProcessAlive && _engineService!.isAnalyzing) {
        _engineService!.stopAnalysis();
      }

      _activeLease = EngineLease(
        type: EngineLeaseType.none,
        leaseId: ++_nextLeaseId,
        acquiredAt: DateTime.now(),
      );

      notifyListeners();
    } finally {
      final lock = _transitionLock;
      _transitionLock = null;
      if (lock != null && !lock.isCompleted) {
        lock.complete();
      }
    }
  }

  /// Validates whether the given [lease] is still the active owner.
  bool isLeaseValid(EngineLease lease) {
    return _activeLease.leaseId == lease.leaseId && _activeLease.type == lease.type;
  }
}
