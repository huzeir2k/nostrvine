// ABOUTME: Manual test to fetch the published profile from relay
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests if the profile event we just published is actually retrievable

import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';

void main() async {
  Log.info('=== Testing Profile Fetch from relay3.openvine.co ===\n');

  // The public key from the logs
  const publicKey =
      '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
  const eventId =
      '29609a582e97981d74cfb9981be2da6c2802afe8ebb90af3122cbd7cc6a09eb3';

  Log.info('Looking for:');
  Log.info('  Public Key: $publicKey');
  Log.info('  Event ID: $eventId');
  Log.info('  Published at: 1751191804 (2025-06-29T10:10:04.000Z UTC)');

  try {
    // Create HTTP client with SSL bypass (like we fixed in Flutter)
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;

    final wsUrl = Uri.parse('wss://relay3.openvine.co');
    Log.info('\n1. Connecting to $wsUrl...');

    final channel = IOWebSocketChannel.connect(
      wsUrl,
      customClient: httpClient,
    );

    var foundProfile = false;
    String? profileContent;

    // Listen for messages
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);

        if (data is List && data.isNotEmpty) {
          final messageType = data[0];

          if (messageType == 'EVENT') {
            final event = data[2];
            Log.info('\n📄 Received EVENT:');
            Log.info('   ID: ${event['id']}');
            Log.info('   Kind: ${event['kind']}');
            Log.info('   Pubkey: ${event['pubkey']}');
            Log.info('   Created: ${event['created_at']}');
            Log.info('   Content: ${event['content']}');

            if (event['id'] == eventId) {
              Log.info('   🎯 FOUND OUR PUBLISHED PROFILE!');
              foundProfile = true;
              profileContent = event['content'];
            }
          } else if (messageType == 'EOSE') {
            Log.info('\n⏹️ End of stored events (EOSE)');
            if (foundProfile) {
              Log.info('✅ SUCCESS: Profile was found and is retrievable!');
              Log.info('📄 Profile content: $profileContent');
            } else {
              Log.info('❌ PROBLEM: Profile was not found in relay storage');
              Log.info('   This means the relay either:');
              Log.info('   - Rejected the event (but logs showed success)');
              Log.info('   - Has a delay in indexing');
              Log.info('   - Has storage/filtering issues');
            }
          } else if (messageType == 'AUTH') {
            final challenge = data[1];
            Log.info('\n🔐 AUTH challenge: $challenge');
            // For this test, we'll skip AUTH and see if we can read without it
          } else if (messageType == 'NOTICE') {
            Log.info('\n📢 NOTICE: ${data[1]}');
          }
        }
      },
      onError: (error) {
        Log.info('❌ WebSocket error: $error');
      },
      onDone: () {
        Log.info('\n🔌 Connection closed');
        exit(0);
      },
    );

    // Wait for connection
    await Future.delayed(const Duration(seconds: 1));

    // Query for the specific profile by author
    Log.info('\n2. Requesting profile for author: $publicKey');
    final req = jsonEncode([
      'REQ',
      'profile-test',
      {
        'authors': [publicKey],
        'kinds': [0],
        'limit': 5,
      }
    ]);

    Log.info('   Sending: $req');
    channel.sink.add(req);

    // Wait for response
    await Future.delayed(const Duration(seconds: 5));

    // Also try querying by event ID
    Log.info('\n3. Requesting specific event by ID: $eventId');
    final eventReq = jsonEncode([
      'REQ',
      'event-test',
      {
        'ids': [eventId],
      }
    ]);

    Log.info('   Sending: $eventReq');
    channel.sink.add(eventReq);

    // Wait for response
    await Future.delayed(const Duration(seconds: 5));

    await channel.sink.close();
  } catch (e) {
    Log.info('❌ Error: $e');
  }
}
