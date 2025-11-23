import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; 

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _guilds => _db.collection('guilds');

  // Create or Update User
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _users.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }
  // --- GUILD METHODS ---

  Future<void> createGuild(String name, UserModel creator) async {
    // 1. Generate a new Guild ID
    DocumentReference guildRef = _guilds.doc();
    
    GuildModel newGuild = GuildModel(
      id: guildRef.id,
      name: name,
      leaderId: creator.uid,
      members: [creator.uid], // Leader is the first member
      totalSteps: creator.currentSteps,
    );

    // Atomic Transaction: Create Guild AND Update User
    await _db.runTransaction((transaction) async {
      transaction.set(guildRef, newGuild.toMap());
      transaction.update(_users.doc(creator.uid), {'guildId': newGuild.id});
    });
  }

  Future<GuildModel?> getGuild(String guildId) async {
    try {
      DocumentSnapshot doc = await _guilds.doc(guildId).get();
      if (doc.exists) {
        return GuildModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Error getting guild: $e");
      return null;
    }
  }

  // List all guilds for the Join screen
  Future<List<GuildModel>> getAllGuilds() async {
    try {
      QuerySnapshot snapshot = await _guilds.get();
      return snapshot.docs
          .map((doc) => GuildModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching guilds: $e");
      return [];
    }
  }

  //Get Top 10 Guilds by Steps
  Future<List<GuildModel>> getTopGuilds() async {
    try {
      QuerySnapshot snapshot = await _guilds
          .orderBy('totalSteps', descending: true)
          .limit(10)
          .get();
      return snapshot.docs
          .map((doc) => GuildModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching leaderboard: $e");
      return [];
    }
  }

  // Join Guild
  Future<void> joinGuild(String guildId, UserModel user) async {
    DocumentReference guildRef = _guilds.doc(guildId);
    
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(guildRef);
      if (!snapshot.exists) throw Exception("Guild does not exist!");

      // Add user to members array and add their steps to total
      transaction.update(guildRef, {
        'members': FieldValue.arrayUnion([user.uid]),
        'totalSteps': FieldValue.increment(user.currentSteps),
      });

      // Update user profile
      transaction.update(_users.doc(user.uid), {'guildId': guildId});
    });
  }
  
  // Leave Guild logic
  Future<void> leaveGuild(String guildId, UserModel user) async {
    DocumentReference guildRef = _guilds.doc(guildId);
    
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(guildRef);
      if (!snapshot.exists) return;

      transaction.update(guildRef, {
        'members': FieldValue.arrayRemove([user.uid]),
        'totalSteps': FieldValue.increment(-user.currentSteps), // Remove their contribution
      });

      transaction.update(_users.doc(user.uid), {'guildId': null});
    });
  }
}