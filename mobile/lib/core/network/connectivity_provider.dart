import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  
  // Initial check
  final initial = await connectivity.checkConnectivity();
  yield !initial.contains(ConnectivityResult.none);

  // Listen to changes
  await for (final results in connectivity.onConnectivityChanged) {
    yield !results.contains(ConnectivityResult.none);
  }
});
