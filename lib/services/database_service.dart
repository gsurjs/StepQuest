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

    // 2. Save Guild
    await guildRef.set(newGuild.toMap());

    // 3. Update Creator's Profile to include this Guild ID
    await _users.doc(creator.uid).update({'guildId': newGuild.id});
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

  // Join an existing guild (Simple version: joins by ID)
  Future<void> joinGuild(String guildId, UserModel user) async {
    DocumentReference guildRef = _guilds.doc(guildId);
    
    // Atomic Transaction: Add user to array, increment step count
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(guildRef);
      if (!snapshot.exists) throw Exception("Guild does not exist!");

      // Update Guild
      transaction.update(guildRef, {
        'members': FieldValue.arrayUnion([user.uid]),
        'totalSteps': FieldValue.increment(user.currentSteps),
      });

      // Update User
      transaction.update(_users.doc(user.uid), {'guildId': guildId});
    });
  }
}