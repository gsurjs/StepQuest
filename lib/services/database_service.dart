import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; 

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _users => _db.collection('users');

  // Create or Update User
  Future<void> createUser(UserModel user) async {
    try {
      await _users.doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'heroName': user.heroName,
        'heroClass': user.heroClass,
        'level': user.level,
        'xp': user.xp, // [NEW]
        'xpToNextLevel': user.xpToNextLevel, // [NEW]
        'currentSteps': user.currentSteps,
        'maxEnergy': user.maxEnergy,
        'currentEnergy': user.currentEnergy,
        'gold': user.gold,
        'lastSync': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saving user: $e");
    }
  }

  // Get User
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _users.doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return UserModel(
          uid: data['uid'],
          email: data['email'],
          heroName: data['heroName'] ?? 'Unknown Hero',
          heroClass: data['heroClass'] ?? 'Warrior',
          level: data['level'] ?? 1,
          xp: data['xp'] ?? 0, // [NEW]
          xpToNextLevel: data['xpToNextLevel'] ?? 100, // [NEW]
          currentSteps: data['currentSteps'] ?? 0,
          maxEnergy: data['maxEnergy'] ?? 100,
          currentEnergy: data['currentEnergy'] ?? 100,
          gold: data['gold'] ?? 0,
        );
      }
      return null;
    } catch (e) {
      print("Error fetching user: $e");
      return null;
    }
  }
}