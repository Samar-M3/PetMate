import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/errors/app_exception.dart';
import '../models/nearby_owner_model.dart';
import '../services/nearby_service.dart';

enum NearbyPermissionStatus {
  checking,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class NearbyState {
  final NearbyPermissionStatus permissionStatus;
  final int selectedRadius;
  final bool isLoadingLocation;
  final bool isLoadingOwners;
  final bool isLoadingMore;
  final bool isUpdatingVisibility;
  final String? errorMessage;
  final String? locationErrorMessage;
  final List<NearbyOwnerModel> owners;
  final List<NearbyClusterModel> clusters;
  final int total;
  final int page;
  final int limit;
  final bool locationEnabled;
  final String? currentArea;
  final ApproxLocation? userDeviceLocation;
  final int requestSeq;

  const NearbyState({
    this.permissionStatus = NearbyPermissionStatus.checking,
    this.selectedRadius = 10,
    this.isLoadingLocation = false,
    this.isLoadingOwners = false,
    this.isLoadingMore = false,
    this.isUpdatingVisibility = false,
    this.errorMessage,
    this.locationErrorMessage,
    this.owners = const [],
    this.clusters = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 20,
    this.locationEnabled = false,
    this.currentArea,
    this.userDeviceLocation,
    this.requestSeq = 0,
  });

  bool get hasMore => owners.length < total;

  bool get isLocationReady =>
      permissionStatus == NearbyPermissionStatus.granted &&
      userDeviceLocation != null;

  NearbyState copyWith({
    NearbyPermissionStatus? permissionStatus,
    int? selectedRadius,
    bool? isLoadingLocation,
    bool? isLoadingOwners,
    bool? isLoadingMore,
    bool? isUpdatingVisibility,
    String? errorMessage,
    bool clearError = false,
    String? locationErrorMessage,
    bool clearLocationError = false,
    List<NearbyOwnerModel>? owners,
    List<NearbyClusterModel>? clusters,
    int? total,
    int? page,
    int? limit,
    bool? locationEnabled,
    String? currentArea,
    ApproxLocation? userDeviceLocation,
    bool clearDeviceLocation = false,
    int? requestSeq,
  }) {
    return NearbyState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      selectedRadius: selectedRadius ?? this.selectedRadius,
      isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
      isLoadingOwners: isLoadingOwners ?? this.isLoadingOwners,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isUpdatingVisibility: isUpdatingVisibility ?? this.isUpdatingVisibility,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      locationErrorMessage: clearLocationError
          ? null
          : (locationErrorMessage ?? this.locationErrorMessage),
      owners: owners ?? this.owners,
      clusters: clusters ?? this.clusters,
      total: total ?? this.total,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      currentArea: currentArea ?? this.currentArea,
      userDeviceLocation: clearDeviceLocation
          ? null
          : (userDeviceLocation ?? this.userDeviceLocation),
      requestSeq: requestSeq ?? this.requestSeq,
    );
  }
}

final nearbyProvider = NotifierProvider<NearbyNotifier, NearbyState>(
  NearbyNotifier.new,
);

class NearbyNotifier extends Notifier<NearbyState> {
  static const MethodChannel _locationChannel =
      MethodChannel('petmate/location_settings');

  Future<bool>? _inFlightLocationCheck;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _isRequestingEnableDialog = false;

  @override
  NearbyState build() {
    _startServiceStatusListener();
    ref.onDispose(() {
      _serviceStatusSubscription?.cancel();
      _serviceStatusSubscription = null;
    });
    return const NearbyState();
  }

  void _startServiceStatusListener() {
    _serviceStatusSubscription?.cancel();
    try {
      _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen(
        (status) {
          if (status == ServiceStatus.disabled) {
            state = state.copyWith(
              permissionStatus: NearbyPermissionStatus.serviceDisabled,
              isLoadingLocation: false,
              isLoadingOwners: false,
              locationErrorMessage:
                  'Turn on your location to discover pet owners nearby.',
            );
          } else if (status == ServiceStatus.enabled) {
            if (state.permissionStatus ==
                    NearbyPermissionStatus.serviceDisabled ||
                state.userDeviceLocation == null) {
              onAppResumed();
            }
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Some platforms (e.g. web) may not support service status stream
    }
  }

  NearbyService get _service => ref.read(nearbyServiceProvider);

  /// Called every time the user enters NearbyScreen.
  /// Checks GPS service & permission, requests permission once if denied,
  /// and fetches nearby owners if ready.
  Future<void> onScreenEntered() async {
    final ready = await _ensureLocationReady(allowRequestPermission: true);
    if (ready) {
      await _syncGpsAndFetchOwners();
    }
  }

  /// Called when the app resumes from background (e.g., returning from Settings).
  /// Never auto-pops permission dialogs on resume, but always re-evaluates
  /// GPS and permission state.
  Future<void> onAppResumed() async {
    final previousStatus = state.permissionStatus;
    final ready = await _ensureLocationReady(allowRequestPermission: false);
    if (ready) {
      if (previousStatus != NearbyPermissionStatus.granted ||
          state.userDeviceLocation == null) {
        await _syncGpsAndFetchOwners();
      }
    }
  }

  /// Centralized GPS service + permission check.
  /// Deduplicates overlapping checks via [_inFlightLocationCheck].
  Future<bool> _ensureLocationReady({
    required bool allowRequestPermission,
  }) async {
    if (_inFlightLocationCheck != null) {
      return _inFlightLocationCheck!;
    }

    final future = _doEnsureLocationReady(
      allowRequestPermission: allowRequestPermission,
    );
    _inFlightLocationCheck = future;
    try {
      return await future;
    } finally {
      _inFlightLocationCheck = null;
    }
  }

  Future<bool> _doEnsureLocationReady({
    required bool allowRequestPermission,
  }) async {
    state = state.copyWith(
      permissionStatus: NearbyPermissionStatus.checking,
      clearError: true,
      clearLocationError: true,
    );

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          permissionStatus: NearbyPermissionStatus.serviceDisabled,
          isLoadingLocation: false,
          isLoadingOwners: false,
          locationErrorMessage:
              'Turn on your location to discover pet owners nearby.',
        );
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && allowRequestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        state = state.copyWith(
          permissionStatus: NearbyPermissionStatus.denied,
          isLoadingLocation: false,
          isLoadingOwners: false,
          locationErrorMessage:
              'Location permission is needed to discover pet owners around you.',
        );
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          permissionStatus: NearbyPermissionStatus.deniedForever,
          isLoadingLocation: false,
          isLoadingOwners: false,
          locationErrorMessage:
              'Location permission is permanently denied. Please enable it in app settings to discover nearby pet owners.',
        );
        return false;
      }

      state = state.copyWith(
        permissionStatus: NearbyPermissionStatus.granted,
        clearLocationError: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        permissionStatus: NearbyPermissionStatus.denied,
        isLoadingLocation: false,
        isLoadingOwners: false,
        locationErrorMessage: 'Unable to verify device location status.',
      );
      return false;
    }
  }

  /// Explicit permission/location action triggered by user tapping Allow / Retry.
  Future<void> requestPermissionAndLoad() async {
    final ready = await _ensureLocationReady(allowRequestPermission: true);
    if (ready) {
      await _syncGpsAndFetchOwners();
    }
  }

  /// Triggers the native Android LocationSettingsRequest resolution dialog
  /// ("Turn on device location?") without leaving the app or opening Settings.
  Future<void> enableLocationServiceAndLoad() async {
    if (_isRequestingEnableDialog) return;
    _isRequestingEnableDialog = true;

    try {
      bool enabled = false;
      if (!kIsWeb && Platform.isAndroid) {
        enabled =
            await _locationChannel.invokeMethod<bool>('requestEnableLocation') ??
                false;
      } else {
        enabled = await Geolocator.isLocationServiceEnabled();
      }

      if (!enabled) {
        state = state.copyWith(
          permissionStatus: NearbyPermissionStatus.serviceDisabled,
          isLoadingLocation: false,
          isLoadingOwners: false,
          locationErrorMessage:
              'Turn on your location to discover pet owners nearby.',
        );
        return;
      }

      final ready = await _ensureLocationReady(allowRequestPermission: true);
      if (ready) {
        await _syncGpsAndFetchOwners();
      }
    } on PlatformException {
      state = state.copyWith(
        permissionStatus: NearbyPermissionStatus.serviceDisabled,
        isLoadingLocation: false,
        isLoadingOwners: false,
        locationErrorMessage:
            'Turn on your location to discover pet owners nearby.',
      );
    } finally {
      _isRequestingEnableDialog = false;
    }
  }

  /// Retrieves actual device GPS coordinates, sends to POST /api/owners/location,
  /// updates the map's current user location, and fetches nearby owners.
  Future<void> _syncGpsAndFetchOwners({int? seq}) async {
    if (state.isLoadingLocation) return;

    state = state.copyWith(
      isLoadingLocation: true,
      clearLocationError: true,
      clearError: true,
    );

    try {
      // Double-check GPS service right before querying position
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoadingLocation: false,
          permissionStatus: NearbyPermissionStatus.serviceDisabled,
          locationErrorMessage:
              'Turn on your location to discover pet owners nearby.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final deviceLocation = ApproxLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final updated = await _service.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      state = state.copyWith(
        isLoadingLocation: false,
        permissionStatus: NearbyPermissionStatus.granted,
        locationEnabled: updated.locationEnabled,
        currentArea: updated.area ?? state.currentArea,
        userDeviceLocation: deviceLocation,
      );

      await fetchNearbyOwners(resetPage: true, seq: seq);
    } on LocationServiceDisabledException {
      state = state.copyWith(
        isLoadingLocation: false,
        permissionStatus: NearbyPermissionStatus.serviceDisabled,
        locationErrorMessage:
            'Turn on your location to discover pet owners nearby.',
      );
    } on PermissionDeniedException {
      state = state.copyWith(
        isLoadingLocation: false,
        permissionStatus: NearbyPermissionStatus.denied,
        locationErrorMessage:
            'Location permission is needed to discover pet owners around you.',
      );
    } on TimeoutException {
      state = state.copyWith(
        isLoadingLocation: false,
        locationErrorMessage:
            'Location lookup timed out. Please ensure GPS signal is available and tap Retry.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingLocation: false,
        errorMessage: _extractErrorMessage(
          e,
          fallback: 'Unable to retrieve your current location.',
        ),
      );
    }
  }

  /// Selecting 5 km / 10 km / 20 km:
  /// 1. Check GPS & permission (request if needed).
  /// 2. If granted & enabled, retrieve latest GPS, update backend, and fetch nearby owners.
  Future<void> changeRadius(int radius) async {
    final nextSeq = state.requestSeq + 1;
    state = state.copyWith(
      selectedRadius: radius,
      requestSeq: nextSeq,
      page: 1,
      clearError: true,
    );

    final ready = await _ensureLocationReady(allowRequestPermission: true);
    if (!ready) {
      if (state.permissionStatus == NearbyPermissionStatus.serviceDisabled) {
        await enableLocationServiceAndLoad();
      }
      return;
    }

    await _syncGpsAndFetchOwners(seq: nextSeq);
  }

  /// Refresh button / pull-to-refresh follows the exact same process:
  /// Check GPS & permission -> get latest GPS -> update backend -> fetch nearby owners.
  Future<void> refresh() async {
    final nextSeq = state.requestSeq + 1;
    state = state.copyWith(requestSeq: nextSeq, clearError: true);

    final ready = await _ensureLocationReady(allowRequestPermission: true);
    if (!ready) {
      if (state.permissionStatus == NearbyPermissionStatus.serviceDisabled) {
        await enableLocationServiceAndLoad();
      }
      return;
    }

    await _syncGpsAndFetchOwners(seq: nextSeq);
  }

  Future<void> fetchNearbyOwners({
    bool resetPage = false,
    int? seq,
  }) async {
    if (state.permissionStatus != NearbyPermissionStatus.granted ||
        state.userDeviceLocation == null) {
      return;
    }

    final activeSeq = seq ?? (state.requestSeq + 1);
    final targetPage = resetPage ? 1 : state.page;

    state = state.copyWith(
      requestSeq: activeSeq,
      isLoadingOwners: resetPage,
      isLoadingMore: !resetPage,
      clearError: true,
    );

    try {
      final res = await _service.fetchNearbyOwners(
        radius: state.selectedRadius,
        page: targetPage,
        limit: state.limit,
      );

      if (state.requestSeq != activeSeq) return;

      final combinedOwners = resetPage
          ? res.owners
          : [...state.owners, ...res.owners];

      state = state.copyWith(
        isLoadingOwners: false,
        isLoadingMore: false,
        owners: combinedOwners,
        clusters: resetPage ? res.clusters : [...state.clusters, ...res.clusters],
        total: res.total,
        page: res.page,
        locationEnabled:
            res.currentUser?.locationEnabled ?? state.locationEnabled,
        currentArea: res.currentUser?.area ?? state.currentArea,
      );
    } catch (e) {
      if (state.requestSeq != activeSeq) return;
      state = state.copyWith(
        isLoadingOwners: false,
        isLoadingMore: false,
        errorMessage: _extractErrorMessage(
          e,
          fallback: 'Failed to load nearby pet owners.',
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoadingOwners || !state.hasMore) return;
    if (state.permissionStatus != NearbyPermissionStatus.granted) return;
    state = state.copyWith(page: state.page + 1);
    await fetchNearbyOwners(resetPage: false, seq: state.requestSeq);
  }

  Future<void> toggleVisibility(bool enabled) async {
    if (state.isUpdatingVisibility) return;
    final previous = state.locationEnabled;
    state = state.copyWith(
      locationEnabled: enabled,
      isUpdatingVisibility: true,
    );

    try {
      final confirmed = await _service.updateLocationVisibility(enabled);
      state = state.copyWith(
        locationEnabled: confirmed,
        isUpdatingVisibility: false,
      );
    } catch (e) {
      state = state.copyWith(
        locationEnabled: previous,
        isUpdatingVisibility: false,
        errorMessage: _extractErrorMessage(
          e,
          fallback: 'Could not update location visibility.',
        ),
      );
    }
  }

  Future<void> openAppPermissionSettings() async {
    await Geolocator.openAppSettings();
  }

  String _extractErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) return error.message;
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isNotEmpty ? text : fallback;
  }
}
