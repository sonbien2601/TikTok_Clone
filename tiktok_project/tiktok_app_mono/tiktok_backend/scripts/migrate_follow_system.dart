// tiktok_backend/scripts/migrate_follow_system.dart
// Script to add follow system fields to existing users

import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';

Future<void> main() async {
  // Database connection
  final db = Db('mongodb://localhost:27017/tiktok_db');
  await db.open();
  
  print('[Migration] Connected to database');
  
  try {
    final usersCollection = db.collection('users');
    
    // Get all users
    final users = await usersCollection.find().toList();
    print('[Migration] Found ${users.length} users to migrate');
    
    int migratedCount = 0;
    
    for (var user in users) {
      final userId = user['_id'] as ObjectId;
      
      // Check if user already has follow fields
      if (user.containsKey('following') && user.containsKey('followers')) {
        print('[Migration] User ${user['username']} already has follow fields, skipping');
        continue;
      }
      
      // Add follow fields
      final updateResult = await usersCollection.updateOne(
        where.id(userId),
        modify
          .set('following', <ObjectId>[])
          .set('followers', <ObjectId>[])
          .set('followingCount', 0)
          .set('followersCount', 0)
          .set('updatedAt', DateTime.now().toIso8601String())
      );
      
      if (updateResult.isSuccess) {
        migratedCount++;
        print('[Migration] ✅ Migrated user: ${user['username']}');
      } else {
        print('[Migration] ❌ Failed to migrate user: ${user['username']}');
      }
    }
    
    print('[Migration] 🎉 Migration completed! Migrated $migratedCount users');
    
    // Verify migration
    final migratedUsers = await usersCollection.find({
      'following': {'\$exists': true},
      'followers': {'\$exists': true},
      'followingCount': {'\$exists': true},
      'followersCount': {'\$exists': true},
    }).toList();
    
    print('[Migration] ✅ Verification: ${migratedUsers.length} users now have follow fields');
    
  } catch (e, stackTrace) {
    print('[Migration] ❌ Error during migration: $e');
    print('[Migration] Stack trace: $stackTrace');
  } finally {
    await db.close();
    print('[Migration] Database connection closed');
  }
}

// Run this script with: dart run scripts/migrate_follow_system.dart