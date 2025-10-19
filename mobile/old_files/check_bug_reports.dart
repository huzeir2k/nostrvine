// ABOUTME: Debug script to check if bug reports (kind 1059) are arriving at relays
// ABOUTME: Queries relay for gift-wrapped NIP-17 messages to verify bug report delivery

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  // Support npub from BugReportConfig
  const supportPubkey = '5c82a509b4f8e5da9a110e76f92fe68bc9de88c957a5435017e2f535f7db0f1f';

  print('🔍 Checking for bug reports (kind 1059 gift-wrapped messages)...');
  print('Support pubkey: $supportPubkey');

  // Connect to relay
  final relayUrl = 'wss://relay3.openvine.co';
  print('\n📡 Connecting to $relayUrl...');

  try {
    final channel = WebSocketChannel.connect(Uri.parse(relayUrl));

    // Subscribe to kind 1059 events (gift-wrapped messages) for support pubkey
    final subscription = jsonEncode([
      'REQ',
      'bug_reports_check',
      {
        'kinds': [1059], // NIP-17 gift-wrapped messages
        'p': [supportPubkey], // Messages addressed to support pubkey
        'limit': 20,
      }
    ]);

    print('📨 Subscribing to kind 1059 events for support pubkey...');
    channel.sink.add(subscription);

    // Also check relay.nos.social (backup relay)
    final channel2 = WebSocketChannel.connect(Uri.parse('wss://relay.nos.social'));
    channel2.sink.add(subscription);

    var eventCount = 0;
    var relay1Received = false;
    var relay2Received = false;

    // Listen for events
    await for (final message in channel.stream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        print('\n⏱️  Timeout reached');
        sink.close();
      },
    )) {
      final data = jsonDecode(message as String) as List;

      if (data[0] == 'EVENT') {
        eventCount++;
        relay1Received = true;
        final event = data[2] as Map<String, dynamic>;
        final eventId = event['id'] as String;
        final createdAt = event['created_at'] as int;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

        print('\n✅ Found gift-wrapped message #$eventCount:');
        print('   Event ID: $eventId');
        print('   Created: $timestamp');
        print('   From relay: $relayUrl');

        // Show p-tags (recipient pubkeys)
        final tags = event['tags'] as List;
        for (final tag in tags) {
          if (tag[0] == 'p') {
            print('   Recipient (p-tag): ${tag[1]}');
          }
        }
      } else if (data[0] == 'EOSE') {
        print('\n📋 End of stored events from $relayUrl');
        break;
      }
    }

    // Listen to backup relay
    await for (final message in channel2.stream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) {
        print('\n⏱️  Timeout reached for backup relay');
        sink.close();
      },
    )) {
      final data = jsonDecode(message as String) as List;

      if (data[0] == 'EVENT') {
        if (!relay2Received) {
          print('\n📡 Also checking backup relay (relay.nos.social)...');
          relay2Received = true;
        }
        eventCount++;
        final event = data[2] as Map<String, dynamic>;
        final eventId = event['id'] as String;
        final createdAt = event['created_at'] as int;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

        print('\n✅ Found gift-wrapped message #$eventCount:');
        print('   Event ID: $eventId');
        print('   Created: $timestamp');
        print('   From relay: relay.nos.social');
      } else if (data[0] == 'EOSE') {
        print('\n📋 End of stored events from relay.nos.social');
        break;
      }
    }

    print('\n' + '=' * 60);
    if (eventCount == 0) {
      print('❌ No bug reports found on either relay!');
      print('\nPossible reasons:');
      print('  1. NostrKeyManager not initialized (check logs for "NostrKeyManager initialized")');
      print('  2. Bug report failed to send (check logs for "Failed to send bug report")');
      print('  3. Relay rejected the event');
      print('  4. Bug report not submitted yet');
    } else {
      print('✅ Found $eventCount gift-wrapped message(s) total');
      if (relay1Received) print('   - relay3.openvine.co: ✓');
      if (relay2Received) print('   - relay.nos.social: ✓');
    }
    print('=' * 60);

    channel.sink.close();
    channel2.sink.close();
  } catch (e, stack) {
    print('\n❌ Error: $e');
    print('Stack trace: $stack');
  }
}
