// ABOUTME: Tests for ProofModeAttestationService configuration management
// ABOUTME: Verifies GCP Project ID is fetched from config instead of hardcoded

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_config.dart';

void main() {
  group('ProofModeAttestationService Configuration', () {
    test('should provide GCP Project ID from config', () async {
      // Test that gcpProjectId getter exists and returns an integer
      final gcpProjectId = await ProofModeConfig.gcpProjectId;

      expect(gcpProjectId, isA<int>());
      expect(gcpProjectId, isNotNull);
    });

    test('should return default GCP Project ID when not configured', () async {
      // When no configuration is set, should return 0 as default
      final gcpProjectId = await ProofModeConfig.gcpProjectId;

      expect(gcpProjectId, equals(0));
    });
  });
}
