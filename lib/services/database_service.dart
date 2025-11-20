import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // Import UserModel from main

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection Reference
  CollectionReference get _users => _db.collection('users');

  // 1. Create User (Called when Registering)
  Future<void> createUser(UserModel user) async {
    try {
      await _users.doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'heroName': user.heroName,
        'heroClass': user.heroClass,
        'level': user.level,
        'currentSteps': user.currentSteps,
        'maxEnergy': user.maxEnergy,
        'currentEnergy': user.currentEnergy,
        'gold': user.gold,
        'lastSync': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error creating user DB entry: $e");
      throw e;
    }
  }

  // 2. Get User (Called when Logging in)
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