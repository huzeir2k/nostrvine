// ABOUTME: Check if a specific event ID exists on the relays
// ABOUTME: Used to verify NIP-17 bug reports were actually stored

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  // Event ID from the logs
  const eventId = 'de9424aa64b7c66b1261fd6b0e2babdc224058fc5cdcfd598caafd5674f99978';

  print('🔍 Checking for specific event: $eventId');

  // Try both relays
  final relays = [
    'wss://relay3.openvine.co',
    'wss://relay.nos.social',
  ];

  for (final relayUrl in relays) {
    print('\n📡 Querying $relayUrl...');

    try {
      final channel = WebSocketChannel.connect(Uri.parse(relayUrl));

      // Query by event ID
      final subscription = jsonEncode([
        'REQ',
        'check_event',
        {
          'ids': [eventId],
        }
      ]);

      channel.sink.add(subscription);

      var found = false;
      await for (final message in channel.stream.timeout(
        const Duration(seconds: 3),
        onTimeout: (sink) {
          if (!found) {
            print('   ❌ Event NOT found (timeout)');
          }
          sink.close();
        },
      )) {
        final data = jsonDecode(message as String) as List;

        if (data[0] == 'EVENT') {
          found = true;
          final event = data[2] as Map<String, dynamic>;
          print('   ✅ Event FOUND!');
          print('   Kind: ${event['kind']}');
          print('   Created: ${DateTime.fromMillisecondsSinceEpoch((event['created_at'] as int) * 1000)}');

          // Show tags
          final tags = event['tags'] as List;
          print('   Tags:');
          for (final tag in tags) {
            if (tag[0] == 'p') {
              print('     - p: ${tag[1]}');
            }
          }
        } else if (data[0] == 'EOSE') {
          if (!found) {
            print('   ❌ Event NOT found on this relay');
          }
          break;
        }
      }

      channel.sink.close();
    } catch (e) {
      print('   ❌ Error: $e');
    }
  }

  // Also try querying for ANY kind 1059 events (no filters)
  print('\n\n📊 Checking for ANY kind 1059 events on relay3.openvine.co...');
  try {
    final channel = WebSocketChannel.connect(Uri.parse('wss://relay3.openvine.co'));

    final subscription = jsonEncode([
      'REQ',
      'all_1059',
      {
        'kinds': [1059],
        'limit': 5,
      }
    ]);

    channel.sink.add(subscription);

    var count = 0;
    await for (final message in channel.stream.timeout(
      const Duration(seconds: 3),
      onTimeout: (sink) {
        print('Found $count kind 1059 events total');
        sink.close();
      },
    )) {
      final data = jsonDecode(message as String) as List;

      if (data[0] == 'EVENT') {
        count++;
        final event = data[2] as Map<String, dynamic>;
        print('  Event ${event['id']}');
      } else if (data[0] == 'EOSE') {
        print('Found $count kind 1059 events total');
        break;
      }
    }

    channel.sink.close();
  } catch (e) {
    print('Error: $e');
  }
}
