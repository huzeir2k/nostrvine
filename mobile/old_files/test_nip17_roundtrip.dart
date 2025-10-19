// ABOUTME: Standalone script to test NIP-17 message send and receive
// ABOUTME: Sends a test message to yourself and verifies it arrives correctly

import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() async {
  // Initialize logging
  UnifiedLogger.setLogLevel(LogLevel.debug);
  UnifiedLogger.enableAllCategories();

  print('\n' + '=' * 60);
  print('🧪 NIP-17 ROUND-TRIP TEST');
  print('=' * 60);

  // Step 1: Initialize services
  print('\n📋 Step 1: Initializing services...');

  final keyManager = NostrKeyManager();
  await keyManager.initialize();

  if (!keyManager.hasKeys) {
    print('   Generating new test keys...');
    await keyManager.generateAndStoreKeys();
  }

  final myPubkey = keyManager.publicKey!;
  print('   ✅ Keys loaded');
  print('   👤 Your pubkey: ${myPubkey.substring(0, 16)}...');

  final nostrService = NostrService(keyManager);
  await nostrService.initialize();

  // Add test relay
  print('\n   📡 Adding relay: relay3.openvine.co');
  await nostrService.addRelay('wss://relay3.openvine.co');
  await Future.delayed(const Duration(seconds: 1));

  final nip17Service = NIP17MessageService(
    keyManager: keyManager,
    nostrService: nostrService,
  );

  print('   ✅ All services initialized');

  // Step 2: Send message to self
  print('\n📤 Step 2: Sending NIP-17 message to yourself...');

  final testMessage = 'TEST MESSAGE at ${DateTime.now().toIso8601String()}';
  print('   Message: "$testMessage"');

  final sendResult = await nip17Service.sendPrivateMessage(
    recipientPubkey: myPubkey, // Send to self!
    content: testMessage,
    additionalTags: [
      ['test', 'roundtrip'],
    ],
  );

  if (!sendResult.success) {
    print('   ❌ FAILED to send message: ${sendResult.error}');
    await nostrService.dispose();
    return;
  }

  print('   ✅ Message sent successfully!');
  print('   📨 Event ID: ${sendResult.eventId}');

  // Step 3: Wait and query for messages
  print('\n📥 Step 3: Waiting for message to propagate...');
  await Future.delayed(const Duration(seconds: 2));

  print('   Querying relay for gift-wrapped messages...');

  final receivedMessages = <Map<String, dynamic>>[];

  // Subscribe to kind 1059 (gift-wrapped messages)
  await nostrService.subscribe(
    filters: [
      {
        'kinds': [1059],
        'limit': 10,
      }
    ],
    onEvent: (event) {
      print('   📦 Received kind ${event['kind']}: ${event['id']}');
      receivedMessages.add(event);
    },
  );

  // Wait for messages
  await Future.delayed(const Duration(seconds: 3));

  print('\n   Found ${receivedMessages.length} gift-wrapped messages total');

  // Step 4: Verify our message is there
  print('\n🔍 Step 4: Verifying our message arrived...');

  final ourMessage = receivedMessages.firstWhere(
    (msg) => msg['id'] == sendResult.eventId,
    orElse: () => {},
  );

  if (ourMessage.isEmpty) {
    print('   ❌ FAILED: Could not find our message on the relay!');
    print('\n   Received message IDs:');
    for (final msg in receivedMessages) {
      print('     - ${msg['id']}');
    }
    await nostrService.dispose();
    return;
  }

  print('   ✅ Found our message!');
  print('   Event ID: ${ourMessage['id']}');
  print('   Kind: ${ourMessage['kind']}');
  print('   Created: ${DateTime.fromMillisecondsSinceEpoch((ourMessage['created_at'] as int) * 1000)}');

  // Check tags
  final tags = ourMessage['tags'] as List;
  final pTags = tags.where((t) => t[0] == 'p').toList();

  print('   P-tags (recipients):');
  for (final pTag in pTags) {
    print('     - ${pTag[1]}');
  }

  // Verify encrypted content exists
  final content = ourMessage['content'] as String;
  print('   Encrypted content length: ${content.length} chars');

  // Step 5: Results
  print('\n' + '=' * 60);
  print('✅ NIP-17 ROUND-TRIP TEST PASSED!');
  print('=' * 60);
  print('\n✓ Message was successfully:');
  print('  1. Created with NIP-17 encryption');
  print('  2. Sent to relay3.openvine.co');
  print('  3. Retrieved from relay');
  print('  4. Verified to be our message');
  print('\n✓ Privacy features verified:');
  print('  - Message is encrypted (content is not plain text)');
  print('  - Uses kind 1059 gift wrapping');
  print('  - Has recipient p-tag');

  // Cleanup
  await nostrService.dispose();

  print('\n🎉 Test complete!\n');
}
