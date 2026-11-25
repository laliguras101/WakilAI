import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';
import 'session_service.dart';

/// Destination workspace selected by role-based routing (`US-14`).
enum WorkspaceDestination {
  /// Administrative governance console (`AdminWorkspaceScreen`).
  adminWorkspace,

  /// Standard citizen & legal advocate workspace (`MainWorkspaceScreen`).
  mainWorkspace,
}

/// Hook for looking up a user's authoritative role from Firestore or an
/// external role directory when Firebase is active.
typedef FirestoreRoleLookup = Future<WakilUserRole?> Function(
  String uid,
  String identifier,
);

/// Outcome of role resolution (`US-14`).
@immutable
class RoleResolutionResult {
  /// Resolved role (`admin` or `citizen`).
  final WakilUserRole role;

  /// Target workspace route corresponding to [role].
  final WorkspaceDestination destination;

  /// Diagnostic source explaining how [role] was determined.
  final String source;

  /// Creates a [RoleResolutionResult].
  const RoleResolutionResult({
    required this.role,
    required this.destination,
    required this.source,
  });

  /// Convenience flag indicating administrative access.
  bool get isAdmin => role == WakilUserRole.admin;
}

/// Implements `US-14` Role-Based Routing (`admin` / `@wakil.gov.np` -> Admin,
/// else Citizen) with an optional live Firestore role lookup hook and safe
/// offline fallback.
class RoleRoutingService {
  /// Official domain suffix conferring administrative privileges under `US-14`.
  static const String officialAdminDomain = '@wakil.gov.np';

  final FirebaseFirestore? _firestoreOverride;
  final FirestoreRoleLookup? _customRoleLookup;
  final Duration _lookupTimeout;

  /// Creates a [RoleRoutingService].
  ///
  /// Supply [firestore] or [customRoleLookup] to override the default Firestore
  /// lookup when testing or customizing directory schema.
  RoleRoutingService({
    FirebaseFirestore? firestore,
    this._customRoleLookup,
    this._lookupTimeout = const Duration(seconds: 3),
  }) : _firestoreOverride = firestore;

  /// Deterministic synchronous `US-14` rule: identifiers containing `admin` or
  /// ending with `@wakil.gov.np` map to [WakilUserRole.admin]; all others map
  /// to [WakilUserRole.citizen].
  bool isAdminIdentifier(String identifier) {
    final clean = identifier.toLowerCase().trim();
    if (clean.isEmpty) {
      return false;
    }
    return clean.contains('admin') || clean.endsWith(officialAdminDomain);
  }

  /// Synchronously resolves [WakilUserRole] from [identifier].
  WakilUserRole resolveRoleSync(String identifier) {
    return isAdminIdentifier(identifier)
        ? WakilUserRole.admin
        : WakilUserRole.citizen;
  }

  /// Synchronously resolves [WorkspaceDestination] from [identifier].
  WorkspaceDestination destinationForIdentifier(String identifier) {
    return destinationForRole(resolveRoleSync(identifier));
  }

  /// Maps a [WakilUserRole] to its [WorkspaceDestination].
  WorkspaceDestination destinationForRole(WakilUserRole role) {
    switch (role) {
      case WakilUserRole.admin:
        return WorkspaceDestination.adminWorkspace;
      case WakilUserRole.citizen:
        return WorkspaceDestination.mainWorkspace;
    }
  }

  /// Resolves the user's role asynchronously, optionally consulting a custom
  /// hook or the user's Firestore `managed_users` records (`accountStatus ==
  /// 'ADMIN'`) before falling back deterministically to the `US-14` identifier
  /// rule.
  Future<RoleResolutionResult> resolveRole({
    required String identifier,
    String? uid,
    bool allowFirestoreLookup = true,
    bool isTestMode = false,
  }) async {
    if (!isTestMode && allowFirestoreLookup && uid != null && uid.isNotEmpty) {
      final hookedRole = await _lookupViaHooks(uid: uid, identifier: identifier);
      if (hookedRole != null) {
        return RoleResolutionResult(
          role: hookedRole.role,
          destination: destinationForRole(hookedRole.role),
          source: hookedRole.source,
        );
      }
    }

    final fallbackRole = resolveRoleSync(identifier);
    return RoleResolutionResult(
      role: fallbackRole,
      destination: destinationForRole(fallbackRole),
      source: isTestMode ? 'test_mode_rule' : 'identifier_rule',
    );
  }

  Future<({WakilUserRole role, String source})?> _lookupViaHooks({
    required String uid,
    required String identifier,
  }) async {
    if (_customRoleLookup != null) {
      try {
        final role = await _customRoleLookup(uid, identifier).timeout(
          _lookupTimeout,
        );
        if (role != null) {
          return (role: role, source: 'custom_role_lookup');
        }
      } catch (error) {
        debugPrint('Wakil RoleRoutingService custom hook failed: $error');
      }
    }

    final firestore = _firestoreOverride ?? FirebaseBootstrap.firestoreOrNull();
    if (firestore == null) {
      return null;
    }

    try {
      // Matches `firestore.rules` path `/users/{userId}/managed_users/{id}`
      // where `accountStatus` is 'ACTIVE' | 'SUSPENDED' | 'ADMIN'.
      final cleanIdentifier = identifier.trim();
      final query = await firestore
          .collection('users')
          .doc(uid)
          .collection('managed_users')
          .where('email', isEqualTo: cleanIdentifier)
          .limit(1)
          .get()
          .timeout(_lookupTimeout);

      if (query.docs.isEmpty) {
        return null;
      }

      final data = query.docs.first.data();
      final status = (data['accountStatus'] as String? ?? '').toUpperCase();
      if (status == 'ADMIN') {
        return (role: WakilUserRole.admin, source: 'firestore_managed_users');
      }
      if (status == 'ACTIVE') {
        return (
          role: WakilUserRole.citizen,
          source: 'firestore_managed_users',
        );
      }
    } catch (error) {
      debugPrint(
        'Wakil RoleRoutingService Firestore lookup fallback to rule: $error',
      );
    }

    return null;
  }
}
