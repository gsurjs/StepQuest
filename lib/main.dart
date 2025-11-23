import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Timestamp
import 'package:step_quest/services/auth_service.dart'; 
import 'package:step_quest/services/database_service.dart';
import 'package:step_quest/services/step_service.dart';
import 'dart:async';
import 'dart:math';

// ==========================================
// 1. MODELS 
// ==========================================

class UserModel {
  final String uid;
  final String email;
  final String heroName;
  final String heroClass;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int currentSteps;
  final int maxEnergy;
  final int currentEnergy;
  final int gold;
  final String? guildId;
  // Tracking daily progress
  final DateTime? lastLoginDate;
  final List<String> claimedQuestIds;

  UserModel({
    required this.uid,
    required this.email,
    required this.heroName,
    required this.heroClass,
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100,
    this.currentSteps = 0,
    this.maxEnergy = 100,
    this.currentEnergy = 100,
    this.gold = 0,
    this.guildId,
    this.lastLoginDate,
    this.claimedQuestIds = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      heroName: data['heroName'] ?? 'Unknown',
      heroClass: data['heroClass'] ?? 'Warrior',
      level: data['level'] ?? 1,
      xp: data['xp'] ?? 0,
      xpToNextLevel: data['xpToNextLevel'] ?? 100,
      currentSteps: data['currentSteps'] ?? 0,
      maxEnergy: data['maxEnergy'] ?? 100,
      currentEnergy: data['currentEnergy'] ?? 100,
      gold: data['gold'] ?? 0,
      guildId: data['guildId'],
      // Handle Firestore Timestamp conversion
      lastLoginDate: data['lastLoginDate'] != null 
          ? (data['lastLoginDate'] as Timestamp).toDate() 
          : DateTime.now(),
      claimedQuestIds: List<String>.from(data['claimedQuestIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'heroName': heroName,
      'heroClass': heroClass,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'currentSteps': currentSteps,
      'maxEnergy': maxEnergy,
      'currentEnergy': currentEnergy,
      'gold': gold,
      'guildId': guildId,
      'lastLoginDate': lastLoginDate != null ? Timestamp.fromDate(lastLoginDate!) : FieldValue.serverTimestamp(),
      'claimedQuestIds': claimedQuestIds,
    };
  }

  factory UserModel.mock() {
    return UserModel(
      uid: 'test', email: 'test@test.com', heroName: 'Mock Hero', heroClass: 'Warrior',
      currentSteps: 5000, gold: 100
    );
  }
}

// Quest Definition
class Quest {
  final String id;
  final String title;
  final String description;
  final int targetSteps;
  final int rewardGold;
  final int rewardXp;

  Quest(this.id, this.title, this.description, this.targetSteps, this.rewardGold, this.rewardXp);
}

class GuildModel {
  final String id;
  final String name;
  final String leaderId;
  final List<String> members;
  final int totalSteps;

  GuildModel({required this.id, required this.name, required this.leaderId, required this.members, this.totalSteps = 0});

  factory GuildModel.fromMap(Map<String, dynamic> data) {
    return GuildModel(
      id: data['id'] ?? '',
      name: data['name'] ?? 'Unnamed Guild',
      leaderId: data['leaderId'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      totalSteps: data['totalSteps'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'leaderId': leaderId, 'members': members, 'totalSteps': totalSteps};
  }
}

// ==========================================
// 2. STATE MANAGEMENT
// ==========================================

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final StepService _stepService = StepService();
  StreamSubscription? _stepSubscription;
  
  User? _firebaseUser;
  UserModel? _currentUser;
  GuildModel? _currentGuild; 

  // Battle State
  int monsterHp = 100;
  int monsterMaxHp = 100;
  String battleLog = "A wild Goblin appeared!";

  // Daily Quests List
  final List<Quest> dailyQuests = [
    Quest('q1', 'Morning Jog', 'Walk 1,000 steps', 1000, 50, 20),
    Quest('q2', 'Adventurer', 'Walk 5,000 steps', 5000, 150, 50),
    Quest('q3', 'Heroic Journey', 'Walk 10,000 steps', 10000, 500, 200),
  ];

  bool get isAuthenticated => _firebaseUser != null;
  UserModel? get user => _currentUser;
  GuildModel? get guild => _currentGuild;

  AppState() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadUserData(user.uid);
        _initPedometer();
      } else {
        _currentUser = null;
        _currentGuild = null;
        _stepSubscription?.cancel(); 
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String uid) async {
    _currentUser = await _dbService.getUser(uid);
    if (_currentUser == null) {
       _currentUser = UserModel.mock();
    } else {
      // Check for Daily Reset logic
      _checkDailyReset();
      
      if (_currentUser!.guildId != null) {
         _currentGuild = await _dbService.getGuild(_currentUser!.guildId!);
      } else {
        _currentGuild = null;
      }
    }
    notifyListeners();
  }

  // Reset quests if it's a new day
  void _checkDailyReset() {
    if (_currentUser == null || _currentUser!.lastLoginDate == null) return;

    final now = DateTime.now();
    final last = _currentUser!.lastLoginDate!;
    
    // If day, month, or year is different, it's a new day
    if (now.day != last.day || now.month != last.month || now.year != last.year) {
      print("🌅 New Day Detected! Resetting Quests.");
      _updateUserData(claimedQuests: [], lastLogin: now);
    } else {
      // Just update the login time
      _updateUserData(lastLogin: now);
    }
  }

  // Claim Reward
  void claimQuest(Quest quest) {
    if (_currentUser == null) return;
    
    if (_currentUser!.claimedQuestIds.contains(quest.id)) return; // Already claimed
    if (_currentUser!.currentSteps < quest.targetSteps) return; // Not finished

    // Give Rewards
    int newGold = _currentUser!.gold + quest.rewardGold;
    int newXp = _currentUser!.xp + quest.rewardXp;
    
    // Add to claimed list
    List<String> newClaimed = List.from(_currentUser!.claimedQuestIds)..add(quest.id);

    // Level Up Logic reuse
    int newLevel = _currentUser!.level;
    int newNextXp = _currentUser!.xpToNextLevel;
    if (newXp >= newNextXp) {
        newLevel++;
        newXp = newXp - newNextXp;
        newNextXp = (newNextXp * 1.5).toInt();
    }

    _updateUserData(
      gold: newGold, 
      xp: newXp, 
      level: newLevel, 
      nextXp: newNextXp,
      claimedQuests: newClaimed
    );
  }

  Future<void> _initPedometer() async {
    bool granted = await _stepService.init();
    if (granted) {
      _stepSubscription = _stepService.stepStream.listen((stepEvent) {
          // Pedometer logic
      });
    }
  }

  void debugAddSteps(int amount) {
    if (_currentUser != null) {
      _updateUserData(steps: _currentUser!.currentSteps + amount);
    }
  }

  // Unified Update Helper
  void _updateUserData({
    int? steps, int? gold, int? xp, int? level, int? nextXp, 
    List<String>? claimedQuests, DateTime? lastLogin
  }) {
     if (_currentUser != null) {
        _currentUser = UserModel(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        heroName: _currentUser!.heroName,
        heroClass: _currentUser!.heroClass,
        level: level ?? _currentUser!.level,
        xp: xp ?? _currentUser!.xp,
        xpToNextLevel: nextXp ?? _currentUser!.xpToNextLevel,
        currentSteps: steps ?? _currentUser!.currentSteps,
        maxEnergy: _currentUser!.maxEnergy,
        currentEnergy: _currentUser!.currentEnergy,
        gold: gold ?? _currentUser!.gold,
        guildId: _currentUser!.guildId,
        lastLoginDate: lastLogin ?? _currentUser!.lastLoginDate,
        claimedQuestIds: claimedQuests ?? _currentUser!.claimedQuestIds,
      );
      notifyListeners();
      _dbService.createUser(_currentUser!);
     }
  }

  // Guild Wrappers
  Future<void> createGuild(String name) async {
    if (_currentUser == null) return;
    await _dbService.createGuild(name, _currentUser!);
    await _loadUserData(_currentUser!.uid);
  }
  Future<void> joinGuild(String guildId) async {
    if (_currentUser == null) return;
    await _dbService.joinGuild(guildId, _currentUser!);
    await _loadUserData(_currentUser!.uid);
  }
  Future<void> leaveGuild() async {
    if (_currentUser == null || _currentGuild == null) return;
    await _dbService.leaveGuild(_currentGuild!.id, _currentUser!);
    await _loadUserData(_currentUser!.uid);
  }
  Future<List<GuildModel>> getAvailableGuilds() async {
    return await _dbService.getAllGuilds();
  }

  // Battle Logic
  Future<void> attackMonster() async {
    if (_currentUser == null) return;
    const int cost = 100;
    if (_currentUser!.currentSteps < cost) {
      battleLog = "Need $cost steps! Walk more.";
      notifyListeners();
      return;
    }
    int newSteps = _currentUser!.currentSteps - cost;
    int damage = Random().nextInt(15) + 10;
    monsterHp -= damage;
    battleLog = "Attack ($cost steps) dealt $damage DMG!";

    int newGold = _currentUser!.gold;
    int newXp = _currentUser!.xp;
    int newLevel = _currentUser!.level;
    int newNextXp = _currentUser!.xpToNextLevel;

    if (monsterHp <= 0) {
      monsterHp = 100;
      int reward = Random().nextInt(50) + 20;
      newGold += reward;
      newXp += 50;
      battleLog = "Victory! +$reward G, +50 XP";
      if (newXp >= newNextXp) {
        newLevel++;
        newXp = newXp - newNextXp;
        newNextXp = (newNextXp * 1.5).toInt();
        battleLog += "\n🎉 LEVEL UP!";
      }
    }
    _updateUserData(steps: newSteps, gold: newGold, xp: newXp, level: newLevel, nextXp: newNextXp);
  }

  Future<void> defendAction() async {
    if (_currentUser == null) return;
    const int cost = 50; 
    if (_currentUser!.currentSteps < cost) {
      battleLog = "Need $cost steps.";
      notifyListeners();
      return;
    }
    battleLog = "Defend ($cost steps) - Blocked!";
    _updateUserData(steps: _currentUser!.currentSteps - cost);
  }

  Future<void> login(String email, String password) async => await _authService.signIn(email, password);
  Future<void> register(String email, String password) async {
    User? user = await _authService.signUp(email, password);
    if (user != null) {
      UserModel newUser = UserModel(uid: user.uid, email: email, heroName: "New Hero", heroClass: "Warrior");
      await _dbService.createUser(newUser);
    }
  }
  Future<void> logout() async => await _authService.signOut();
}

// ==========================================
// 3. THEME
// ==========================================
class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    primaryColor: const Color(0xFFEAB308),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFEAB308), secondary: Color(0xFF3B82F6),
      surface: Color(0xFF1E293B), error: Color(0xFFEF4444),
    ),
    fontFamily: 'Georgia',
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEAB308)),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ==========================================
// 4. MAIN ENTRY
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (e) { print("Firebase Error: $e"); }
  runApp(const StepQuestApp());
}

class StepQuestApp extends StatefulWidget {
  const StepQuestApp({super.key});
  @override
  State<StepQuestApp> createState() => _StepQuestAppState();
}

class _StepQuestAppState extends State<StepQuestApp> {
  final AppState _appState = AppState();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, child) {
        return MaterialApp(
          title: 'StepQuest',
          theme: AppTheme.darkTheme,
          debugShowCheckedModeBanner: false,
          home: _appState.isAuthenticated ? MainScaffold(appState: _appState) : LoginScreen(appState: _appState),
        );
      },
    );
  }
}

// ==========================================
// 5. SCREENS
// ==========================================

class LoginScreen extends StatefulWidget {
  final AppState appState;
  const LoginScreen({super.key, required this.appState});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isLogin = true; 
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) await widget.appState.login(_emailController.text.trim(), _passwordController.text.trim());
      else await widget.appState.register(_emailController.text.trim(), _passwordController.text.trim());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.directions_walk, size: 80, color: Color(0xFFEAB308)),
                const SizedBox(height: 20),
                Text("StepQuest", style: Theme.of(context).textTheme.displayLarge),
                Text(_isLogin ? "Enter the Tavern" : "Join the Guild", style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  validator: (val) => val!.contains('@') ? null : 'Invalid Email',
                  decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  validator: (val) => val!.length > 5 ? null : 'Password too short',
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                    child: _isLoading ? const CircularProgressIndicator() : Text(_isLogin ? "LOGIN" : "REGISTER", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "New Hero? Create Account" : "Already have a hero? Login"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  final AppState appState;
  const MainScaffold({super.key, required this.appState});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(appState: widget.appState),
      BattleScreen(appState: widget.appState),
      QuestScreen(appState: widget.appState),
      GuildScreen(appState: widget.appState),
      ProfileScreen(appState: widget.appState),
    ];
    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).primaryColor.withOpacity(0.5),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'World'),
          NavigationDestination(icon: Icon(Icons.sports_martial_arts), label: 'Battle'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Quests'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Guild'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Hero'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final AppState appState;
  const DashboardScreen({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => appState.debugAddSteps(500),
        label: const Text("Simulate 500 Steps"),
        icon: const Icon(Icons.directions_run),
        backgroundColor: Colors.green,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome back,", style: Theme.of(context).textTheme.bodySmall),
                      Text(user.heroName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFFEAB308))),
                    ],
                  ),
                  Chip(
                    avatar: const Icon(Icons.monetization_on, size: 16, color: Colors.black),
                    label: Text("${user.gold} G", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    backgroundColor: const Color(0xFFEAB308),
                  )
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: (user.currentSteps / 10000).clamp(0.0, 1.0),
                        strokeWidth: 20,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        color: Colors.green,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk, size: 40, color: Colors.green),
                        Text("${user.currentSteps}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                        const Text("STEPS", style: TextStyle(letterSpacing: 2, fontSize: 10)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BattleScreen extends StatelessWidget {
  final AppState appState;
  const BattleScreen({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 40,
                    child: Column(
                      children: [
                        Text("Forest Goblin", style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            value: appState.monsterHp / appState.monsterMaxHp,
                            color: Colors.red,
                            backgroundColor: Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text("👺", style: TextStyle(fontSize: 100)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.green[900]!.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_walk, color: Colors.green),
                        const SizedBox(width: 8),
                        Text("Available Steps: ${appState.user?.currentSteps ?? 0}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[800]!)),
                    child: Center(
                      child: Text(appState.battleLog, style: const TextStyle(fontFamily: 'Courier', color: Colors.greenAccent), textAlign: TextAlign.center),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => appState.attackMonster(),
                          icon: const Icon(Icons.flash_on),
                          label: const Text("ATTACK\n(100 Steps)"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => appState.defendAction(),
                          icon: const Icon(Icons.shield),
                          label: const Text("DEFEND\n(50 Steps)"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- QUEST SCREEN (UPDATED) ---
class QuestScreen extends StatelessWidget {
  final AppState appState;
  const QuestScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final steps = appState.user?.currentSteps ?? 0;
    final claimed = appState.user?.claimedQuestIds ?? [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Quest Board", style: Theme.of(context).textTheme.displayLarge),
            const Text("Daily challenges reset at midnight.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            // Dynamic List from AppState
            ...appState.dailyQuests.map((quest) {
              bool isCompleted = steps >= quest.targetSteps;
              bool isClaimed = claimed.contains(quest.id);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isClaimed ? Colors.green[900]!.withOpacity(0.3) : Theme.of(context).cardTheme.color,
                child: ListTile(
                  leading: Icon(
                    isClaimed ? Icons.check_circle : (isCompleted ? Icons.stars : Icons.circle_outlined), 
                    color: isClaimed ? Colors.green : (isCompleted ? Colors.amber : Colors.grey)
                  ),
                  title: Text(quest.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quest.description),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (steps / quest.targetSteps).clamp(0.0, 1.0),
                        backgroundColor: Colors.black26,
                        color: isCompleted ? Colors.green : Colors.blue,
                        minHeight: 6,
                      )
                    ],
                  ),
                  trailing: isClaimed 
                    ? const Text("DONE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    : ElevatedButton(
                        onPressed: isCompleted ? () => appState.claimQuest(quest) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted ? Colors.amber : Colors.grey[800],
                          foregroundColor: Colors.black,
                        ),
                        child: Text(isCompleted ? "CLAIM" : "${quest.rewardGold} G"),
                      ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class GuildScreen extends StatelessWidget {
  final AppState appState;
  const GuildScreen({super.key, required this.appState});

  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<GuildModel>>(
        future: appState.getAvailableGuilds(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AlertDialog(content: LinearProgressIndicator());
          final guilds = snapshot.data!;
          return AlertDialog(
            title: const Text("Join a Guild"),
            content: SizedBox(
              width: double.maxFinite,
              child: guilds.isEmpty 
                ? const Text("No guilds found. Create one!") 
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: guilds.length,
                    itemBuilder: (ctx, i) => ListTile(
                      title: Text(guilds[i].name),
                      subtitle: Text("${guilds[i].members.length} members"),
                      trailing: ElevatedButton(
                        onPressed: () {
                          appState.joinGuild(guilds[i].id);
                          Navigator.pop(context);
                        },
                        child: const Text("JOIN"),
                      ),
                    ),
                  ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL"))],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guild = appState.guild;
    final TextEditingController guildNameController = TextEditingController();

    if (guild == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.groups, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text("No Guild", style: Theme.of(context).textTheme.displayMedium),
              const Text("Join forces with others to earn bonus loot!", textAlign: TextAlign.center),
              const SizedBox(height: 32),
              TextField(
                controller: guildNameController,
                decoration: const InputDecoration(labelText: "Guild Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (guildNameController.text.isNotEmpty) {
                      appState.createGuild(guildNameController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  child: const Text("CREATE NEW GUILD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () => _showJoinDialog(context), 
                child: const Text("Join Existing Guild")
              )
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(Icons.shield_moon, size: 60, color: Colors.blue)),
            const SizedBox(height: 10),
            Center(child: Text(guild.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            const Center(child: Text("Guild Level 1", style: TextStyle(color: Colors.blue))),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(Icons.hiking, color: Colors.green),
                title: const Text("Total Steps"),
                trailing: Text("${guild.totalSteps}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Members (${guild.members.length})", style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () => appState.leaveGuild(), 
                  child: const Text("Leave Guild", style: TextStyle(color: Colors.red))
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: guild.members.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: CircleAvatar(child: Text("${i+1}")),
                  title: Text(guild.members[i] == appState.user?.uid ? "You" : "Member ID: ${guild.members[i].substring(0, 5)}..."),
                  trailing: const Icon(Icons.star, size: 16, color: Colors.amber),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final AppState appState;
  const ProfileScreen({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    if (user == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(user.heroName, style: Theme.of(context).textTheme.headlineMedium),
            Text("Level ${user.level} ${user.heroClass}", style: const TextStyle(color: Color(0xFFEAB308))),
            const SizedBox(height: 8),
            SizedBox(width: 200, child: LinearProgressIndicator(value: user.xp / user.xpToNextLevel, backgroundColor: Colors.grey[800], color: Colors.purpleAccent, minHeight: 10)),
            Text("${user.xp} / ${user.xpToNextLevel} XP", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5,
                children: [
                  _buildStatCard(context, "Strength", "24"),
                  _buildStatCard(context, "Agility", "18"),
                  _buildStatCard(context, "Total Steps", "${user.currentSteps}"),
                  _buildStatCard(context, "Gold", "${user.gold}"),
                ],
              ),
            ),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: appState.logout, child: const Text("LOGOUT")))
          ],
        ),
      ),
    );
  }
  Widget _buildStatCard(BuildContext context, String label, String value) {
    return Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))]));
  }
}