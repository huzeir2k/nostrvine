// ABOUTME: Debug script to dump full Nostr events for specific video IDs
// ABOUTME: Used to troubleshoot cdn.divine.video thumbnail 404 issues

import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr;

Future<void> main() async {
  // Video IDs with failing thumbnails
  final videoIds = [
    '9865fe68ab26ee5a4db7ab5c4e44b3cb4b1b5c6e87f942e5a6c19acaff6c52f9',
    'feb05464c0c6e01edbb5d17c20354cb53ba99a86c36dcf5dbdf33ae80a4f10f1',
    '6e4398b94d1b9d16adf4fe6b49f5e89fcc7e5e2b1e96b1b1c7d6c9a3e3e0e0f4',
    '42ab6b019c3f5e1b3f3f5e1b3f3f5e1b3f3f5e1b3f3f5e1b3f3f5e1b3f3f5e1b',
  ];

  print('Connecting to relay...');

  // Connect to the relay
  final client = nostr.Client();
  await client.addRelay('wss://relay3.openvine.co');
  await client.connect();

  print('Querying for video events...');

  for (final id in videoIds) {
    print('\n=== EVENT ID: $id ===');

    // Query for this specific event
    final filter = nostr.Filter(
      ids: [id],
      kinds: [22, 34236, 34235],
    );

    final events = await client.getEvents([filter]);

    if (events.isEmpty) {
      print('⚠️  No event found for ID: $id');
      continue;
    }

    final event = events.first;

    // Dump full event as JSON
    final eventJson = {
      'id': event.id,
      'pubkey': event.pubkey,
      'created_at': event.createdAt,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'sig': event.sig,
    };

    print(JsonEncoder.withIndent('  ').convert(eventJson));
    print('');
  }

  await client.disconnect();
  print('Done!');
}
