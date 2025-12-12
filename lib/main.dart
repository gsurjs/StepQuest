import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:step_quest/services/auth_service.dart';
import 'package:step_quest/services/database_service.dart';
import 'package:step_quest/services/step_service.dart';
import 'dart:async';
import 'dart:math';
import 'firebase_options.dart';

// ==========================================
// 1. DATA MODELS & MONSTER LIST
// ==========================================

class Monster {
  final String id;
  final String name;
  final String assetPath;
  final int maxHealth;

  Monster({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.maxHealth,
  });
}

// THE MASTER LIST OF MONSTERS
final List<Monster> allMonsters = [
  Monster(id: 'm_01', name: 'Green Slime', assetPath: 'assets/monsters/slime.png', maxHealth: 50),
  Monster(id: 'm_02', name: 'Giant Rat', assetPath: 'assets/monsters/rat.png', maxHealth: 60),
  Monster(id: 'm_03', name: 'Cave Bat', assetPath: 'assets/monsters/bat.png', maxHealth: 70),
  Monster(id: 'm_04', name: 'Scout Goblin', assetPath: 'assets/monsters/goblin.png', maxHealth: 100),
  Monster(id: 'm_05', name: 'Skeleton', assetPath: 'assets/monsters/skeleton.png', maxHealth: 110),
  Monster(id: 'm_06', name: 'Orc Grunt', assetPath: 'assets/monsters/orc.png', maxHealth: 150),
  Monster(id: 'm_07', name: 'Spirit', assetPath: 'assets/monsters/ghost.png', maxHealth: 130),
  Monster(id: 'm_08', name: 'Stone Golem', assetPath: 'assets/monsters/golem.png', maxHealth: 200),
  Monster(id: 'm_09', name: 'Young Dragon', assetPath: 'assets/monsters/dragon.png', maxHealth: 300),
  Monster(id: 'm_10', name: 'Dark Knight', assetPath: 'assets/monsters/dark_knight.png', maxHealth: 250),
];

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
  final int lifetimeSteps;  // Never Resets
  final int gold;
  final String? guildId;
  final DateTime? lastLoginDate;
  final List<String> claimedQuestIds;
  final List<String> inventory;

  UserModel({
    required this.uid,
    required this.email,
    required this.heroName,
    required this.heroClass,
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100,
    this.currentSteps = 0,
    this.lifetimeSteps = 0,
    this.maxEnergy = 100,
    this.currentEnergy = 100,
    this.gold = 0,
    this.guildId,
    this.lastLoginDate,
    this.claimedQuestIds = const [],
    this.inventory = const [],
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
      lifetimeSteps: data['lifetimeSteps'] ?? 0,
      maxEnergy: data['maxEnergy'] ?? 100,
      currentEnergy: data['currentEnergy'] ?? 100,
      gold: data['gold'] ?? 0,
      guildId: data['guildId'],
      lastLoginDate: data['lastLoginDate'] != null
          ? (data['lastLoginDate'] as Timestamp).toDate()
          : DateTime.now(),
      claimedQuestIds: List<String>.from(data['claimedQuestIds'] ?? []),
      inventory: List<String>.from(data['inventory'] ?? []),
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
      'lifetimeSteps': lifetimeSteps,
      'maxEnergy': maxEnergy,
      'currentEnergy': currentEnergy,
      'gold': gold,
      'guildId': guildId,
      'lastLoginDate': lastLoginDate != null
          ? Timestamp.fromDate(lastLoginDate!)
          : FieldValue.serverTimestamp(),
      'claimedQuestIds': claimedQuestIds,
      'inventory': inventory,
    };
  }
}

class Item {
  final String id;
  final String name;
  final String icon;
  final String rarity;
  final int price;
  Item(this.id, this.name, this.icon, this.rarity, {this.price = 50});
}

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

class WorldZone {
  final String id;
  final String name;
  final String description;
  final String imageEmoji;
  final int minLevel;
  WorldZone(this.id, this.name, this.description, this.imageEmoji, this.minLevel);
}

// ==========================================
// 2. STATE MANAGEMENT (APP STATE)
// ==========================================

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final StepService _stepService = StepService();
  StreamSubscription? _stepSubscription;

  User? _firebaseUser;
  UserModel? _currentUser;
  GuildModel? _currentGuild;

  late Monster activeMonster; 
  int currentMonsterHp = 50;  
  String battleLog = "A wild monster appeared!";

  WorldZone? _currentZone;
  final List<WorldZone> worldZones = [
    WorldZone('zone_1', 'Whispering Woods', 'A peaceful forest.', '🌲', 1),
    WorldZone('zone_2', 'Stonekeep Caves', 'Dark and dangerous.', '🦇', 3),
    WorldZone('zone_3', 'Molten Core', 'Extreme heat.', '🔥', 5),
  ];
  
  final List<Item> gameItems = [
    Item('potion', 'Health Potion', '🧪', 'Common', price: 50),
    Item('sword_wood', 'Wooden Sword', '🗡️', 'Common', price: 100),
    Item('shield_iron', 'Iron Shield', '🛡️', 'Rare', price: 250),
    Item('boots_speed', 'Boots of Haste', '👢', 'Rare', price: 300),
    Item('ring_power', 'Ring of Power', '💍', 'Legendary', price: 1000),
  ];
  
  final List<Quest> dailyQuests = [
    Quest('q1', 'Early Bird', 'Walk 2,000 steps', 2000, 50, 20),
    Quest('q2', 'Marathoner', 'Walk 10,000 steps', 10000, 150, 50),
    Quest('q3', 'Heroic Journey', 'Walk 15,000 steps', 15000, 500, 200),
  ];

  bool get isAuthenticated => _firebaseUser != null;
  UserModel? get user => _currentUser;
  GuildModel? get guild => _currentGuild;
  WorldZone get currentZone => _currentZone ?? worldZones[0];

  AppState() {
    // Initialize with the first monster
    activeMonster = allMonsters[0];
    currentMonsterHp = activeMonster.maxHealth;
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
    if (_currentUser != null) {
      _checkDailyReset();
      if (_currentUser!.guildId != null) {
        _currentGuild = await _dbService.getGuild(_currentUser!.guildId!);
      }
      _currentZone ??= worldZones[0];
    }
    notifyListeners();
  }

  void _checkDailyReset() {
    if (_currentUser == null || _currentUser!.lastLoginDate == null) return;
    final now = DateTime.now();
    final last = _currentUser!.lastLoginDate!;

    if (now.day != last.day || now.month != last.month || now.year != last.year) {
      print("📅 NEW DAY DETECTED! Resetting Daily Steps...");
      // RESET Daily Steps to 0, but keep Lifetime Steps (passed implicitly via copyWith logic in _updateUserData)
      // Clear claimed quests for the new day
      _updateUserData(
        steps: 0, 
        claimedQuests: [], 
        lastLogin: now
      );
    } else {
      // Same day, just update login time
      _updateUserData(lastLogin: now);
    }
  }

  // --- ACTIONS ---

  void travelToZone(WorldZone zone) {
    if ((_currentUser?.level ?? 1) >= zone.minLevel) {
      _currentZone = zone;
      battleLog = "Traveled to ${zone.name}!";
      notifyListeners();
    } else {
      battleLog = "Level ${zone.minLevel} required to enter!";
      notifyListeners();
    }
  }

  void buyItem(Item item) {
    if (_currentUser == null) return;
    if (_currentUser!.gold >= item.price) {
      int newGold = _currentUser!.gold - item.price;
      List<String> newInventory = List.from(_currentUser!.inventory)..add(item.id);
      _updateUserData(gold: newGold, inventory: newInventory);
      battleLog = "Bought ${item.name}!";
    }
  }

  void claimQuest(Quest quest) {
    if (_currentUser == null) return;
    if (_currentUser!.claimedQuestIds.contains(quest.id)) return;
    if (_currentUser!.currentSteps < quest.targetSteps) return;

    int newGold = _currentUser!.gold + quest.rewardGold;
    int newXp = _currentUser!.xp + quest.rewardXp;
    List<String> newClaimed = List.from(_currentUser!.claimedQuestIds)..add(quest.id);

    int newLevel = _currentUser!.level;
    int newNextXp = _currentUser!.xpToNextLevel;
    if (newXp >= newNextXp) {
      newLevel++;
      newXp = newXp - newNextXp;
      newNextXp = (newNextXp * 1.5).toInt();
    }

    _updateUserData(gold: newGold, xp: newXp, level: newLevel, nextXp: newNextXp, claimedQuests: newClaimed);
  }

  // --- BATTLE LOGIC WITH SPAWN ---

  void spawnRandomMonster() {
    final random = Random();
    List<Monster> candidates = allMonsters.where((m) => m.id != activeMonster.id).toList();
    if (candidates.isEmpty) candidates = allMonsters;
    
    activeMonster = candidates[random.nextInt(candidates.length)];
    currentMonsterHp = activeMonster.maxHealth;
    
    battleLog = "A wild ${activeMonster.name} appeared!";
    notifyListeners();
  }

  Future<void> attackMonster() async {
    if (_currentUser == null) return;
    if (_currentUser!.currentEnergy < 10) {
      battleLog = "Not enough Energy! Walk more.";
      notifyListeners();
      return;
    }

    int newEnergy = _currentUser!.currentEnergy - 10;
    int damage = Random().nextInt(15) + 10;
    
    currentMonsterHp -= damage;
    battleLog = "Hit ${activeMonster.name} for $damage DMG!";

    int newGold = _currentUser!.gold;
    int newXp = _currentUser!.xp;
    List<String> currentInventory = List.from(_currentUser!.inventory);

    if (currentMonsterHp <= 0) {
      currentMonsterHp = 0;
      
      int reward = Random().nextInt(50) + 20;
      newGold += reward;
      newXp += 50;
      battleLog = "Victory! +$reward G, +50 XP";

      if (Random().nextDouble() < 0.3) {
        Item drop = gameItems[Random().nextInt(gameItems.length)];
        currentInventory.add(drop.id);
        battleLog += "\n🎁 Found loot: ${drop.name}!";
      }

      // Spawn next monster immediately
      spawnRandomMonster(); 
    }

    int newLevel = _currentUser!.level;
    int newNextXp = _currentUser!.xpToNextLevel;
    if (newXp >= newNextXp) {
      newLevel++;
      newXp = newXp - newNextXp;
      newNextXp = (newNextXp * 1.5).toInt();
      battleLog += "\n🎉 LEVEL UP!";
    }

    _updateUserData(
        energy: newEnergy,
        gold: newGold,
        xp: newXp,
        level: newLevel,
        nextXp: newNextXp,
        inventory: currentInventory);
  }

  void usePotion() {
    if (_currentUser == null) return;
    if (_currentUser!.inventory.contains('potion')) {
      List<String> newInventory = List.from(_currentUser!.inventory);
      newInventory.remove('potion'); 
      int newEnergy = (_currentUser!.currentEnergy + 50).clamp(0, 100);
      battleLog = "Used Potion! Energy restored.";
      _updateUserData(inventory: newInventory, energy: newEnergy);
    } else {
      battleLog = "No potions!";
      notifyListeners();
    }
  }

  void useSkill() {
    if (_currentUser == null) return;
    if (_currentUser!.currentEnergy < 30) {
      battleLog = "Need 30 Energy!";
      notifyListeners();
      return;
    }
    int damage = Random().nextInt(30) + 20;
    currentMonsterHp -= damage;
    int newEnergy = _currentUser!.currentEnergy - 30;
    battleLog = "Ultimate Skill! $damage DMG!";
    
    if (currentMonsterHp <= 0) {
       spawnRandomMonster();
       battleLog += " (Defeated!)";
    }
    _updateUserData(energy: newEnergy);
  }

  void defendAction() {
    if (_currentUser == null) return;
    if (_currentUser!.currentEnergy < 5) {
      battleLog = "Need 5 Energy.";
      notifyListeners();
      return;
    }
    battleLog = "Defensive Stance active.";
    _updateUserData(energy: _currentUser!.currentEnergy - 5);
  }

  // --- PEDOMETER & DATA SYNC ---
  Future<void> _initPedometer() async {
    bool granted = await _stepService.init();
    if (granted) {
      _stepSubscription = _stepService.stepStream.listen((stepEvent) {
      });
    }
  }

  void debugAddSteps(int amount) {
    if (_currentUser != null) {
      int newDailySteps = _currentUser!.currentSteps + amount;
      int newLifetimeSteps = _currentUser!.lifetimeSteps + amount; // Accumulate lifetime
      
      // Regenerate Energy (1 Energy per 100 steps)
      int energyGain = (amount / 100).floor();
      int newEnergy = (_currentUser!.currentEnergy + energyGain).clamp(0, _currentUser!.maxEnergy);
      
      _updateUserData(
        steps: newDailySteps, 
        lifetimeSteps: newLifetimeSteps,
        energy: newEnergy
      );
    }
  }

  void _updateUserData({
    int? steps, int? lifetimeSteps, int? gold, int? xp, int? level, int? nextXp, int? energy,
    List<String>? claimedQuests, DateTime? lastLogin, List<String>? inventory,
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
        lifetimeSteps: lifetimeSteps ?? _currentUser!.lifetimeSteps,
        maxEnergy: _currentUser!.maxEnergy,
        currentEnergy: energy ?? _currentUser!.currentEnergy,
        gold: gold ?? _currentUser!.gold,
        guildId: _currentUser!.guildId,
        lastLoginDate: lastLogin ?? _currentUser!.lastLoginDate,
        claimedQuestIds: claimedQuests ?? _currentUser!.claimedQuestIds,
        inventory: inventory ?? _currentUser!.inventory,
      );
      notifyListeners();
      _dbService.createUser(_currentUser!);
    }
  }

  Future<void> login(String email, String password) async => await _authService.signIn(email, password);
  Future<void> register(String email, String password, String name, String hClass) async {
    User? user = await _authService.signUp(email, password);
    if (user != null) {
      UserModel newUser = UserModel(uid: user.uid, email: email, heroName: name, heroClass: hClass);
      await _dbService.createUser(newUser);
    }
  }
  Future<void> logout() async => await _authService.signOut();
  Future<void> createGuild(String name) async {
    if (_currentUser != null) await _dbService.createGuild(name, _currentUser!);
    await _loadUserData(_currentUser!.uid);
  }
  Future<void> joinGuild(String guildId) async {
    if (_currentUser != null) await _dbService.joinGuild(guildId, _currentUser!);
    await _loadUserData(_currentUser!.uid);
  }
  Future<void> leaveGuild() async {
    if (_currentUser != null && _currentGuild != null) {
      await _dbService.leaveGuild(_currentGuild!.id, _currentUser!);
      await _loadUserData(_currentUser!.uid);
    }
  }
  Future<List<GuildModel>> getAvailableGuilds() async => await _dbService.getAllGuilds();
  Future<List<GuildModel>> getLeaderboard() async => await _dbService.getTopGuilds();
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
      primary: Color(0xFFEAB308),
      secondary: Color(0xFF3B82F6),
      surface: Color(0xFF1E293B),
      error: Color(0xFFEF4444),
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
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEAB308),
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

// ==========================================
// 4. MAIN ENTRY
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    print("Firebase Error: $e");
  }
  runApp(const StepQuestApp());
}

class StepQuestApp extends StatelessWidget {
  const StepQuestApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepQuest',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const RootHandler(), 
    );
  }
}

class RootHandler extends StatefulWidget {
  const RootHandler({super.key});
  @override
  State<RootHandler> createState() => _RootHandlerState();
}

class _RootHandlerState extends State<RootHandler> {
  final AppState _appState = AppState();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, child) {
        if (_appState.isAuthenticated) {
          return MainScaffold(appState: _appState);
        } else {
          return LoginScreen(appState: _appState);
        }
      },
    );
  }
}

// ==========================================
// 5. SCREENS
// ==========================================

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  final AppState appState;
  const LoginScreen({super.key, required this.appState});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedClass = 'Warrior';
  bool _isLogin = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAB308),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: const Color(0xFFEAB308).withOpacity(0.5), blurRadius: 20)]),
                child: const Icon(Icons.directions_walk, size: 40, color: Colors.black),
              ),
              const SizedBox(height: 24),
              const Text("StepQuest",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFEAB308), fontFamily: 'Georgia')),
              const Text("Turn your walk into an Adventure.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),

              if (!_isLogin) ...[
                Align(alignment: Alignment.centerLeft, child: Text("HERO NAME", style: Theme.of(context).textTheme.labelSmall)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    hintText: "Sir Walker",
                  ),
                ),
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft, child: Text("CLASS", style: Theme.of(context).textTheme.labelSmall)),
                const SizedBox(height: 8),
                Row(
                  children: ['Warrior', 'Rogue', 'Mage'].map((c) {
                    final isSelected = _selectedClass == c;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedClass = c),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEAB308) : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? null : Border.all(color: Colors.grey[800]!),
                          ),
                          child: Center(
                            child: Text(c,
                                style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.grey)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                  hintText: "Email",
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                  hintText: "Password",
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_isLogin) {
                      widget.appState.login(_emailController.text, _passwordController.text);
                    } else {
                      widget.appState.register(_emailController.text, _passwordController.text, _nameController.text, _selectedClass);
                    }
                  },
                  child: Text(_isLogin ? "RESUME ADVENTURE" : "ENTER THE TAVERN >",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Need to create a Hero?" : "Already have a Hero?", style: const TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN SCAFFOLD (TABS) ---
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
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: Theme.of(context).primaryColor.withOpacity(0.5),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Hub'),
          NavigationDestination(icon: Icon(Icons.sports_martial_arts), label: 'Battle'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'Quests'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Guild'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Hero'),
        ],
      ),
    );
  }
}

// --- DASHBOARD ---
class DashboardScreen extends StatelessWidget {
  final AppState appState;
  const DashboardScreen({super.key, required this.appState});

  void _showShop(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("The Merchant", style: Theme.of(context).textTheme.headlineMedium),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: appState.gameItems.length,
                itemBuilder: (ctx, i) {
                  final item = appState.gameItems[i];
                  return ListTile(
                    leading: Text(item.icon, style: const TextStyle(fontSize: 30)),
                    title: Text(item.name),
                    subtitle: Text(item.rarity),
                    trailing: ElevatedButton(
                      onPressed: () {
                        appState.buyItem(item);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      child: Text("${item.price} G", style: const TextStyle(color: Colors.black)),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showZoneSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appState.worldZones.length,
        itemBuilder: (ctx, i) {
          final zone = appState.worldZones[i];
          return ListTile(
            leading: Text(zone.imageEmoji, style: const TextStyle(fontSize: 30)),
            title: Text(zone.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text("Lvl ${zone.minLevel}+"),
            onTap: () {
              appState.travelToZone(zone);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = appState.user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      floatingActionButton: FloatingActionButton(
        onPressed: () => appState.debugAddSteps(500),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Welcome back,", style: TextStyle(color: Colors.grey)),
                      Text(user.heroName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFEAB308))),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[800]!)),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 12, color: Color(0xFFEAB308)),
                        const SizedBox(width: 8),
                        Text("${user.gold} G", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                ],
              ),
              const Spacer(),
              // Circular Progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: (user.currentSteps / 10000).clamp(0.0, 1.0),
                      strokeWidth: 20,
                      backgroundColor: const Color(0xFF1E293B),
                      color: Colors.green,
                    ),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.directions_walk, size: 40, color: Colors.green),
                      const SizedBox(height: 8),
                      Text("${user.currentSteps}",
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text("DAILY STEPS", style: TextStyle(color: Colors.grey, letterSpacing: 1.5)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 40),
              // Energy Bar
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Row(children: [Icon(Icons.bolt, color: Colors.blue), SizedBox(width: 4), Text("Energy")]),
                Text("${user.currentEnergy} / ${user.maxEnergy}", style: const TextStyle(color: Colors.grey)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: user.currentEnergy / user.maxEnergy,
                backgroundColor: const Color(0xFF1E293B),
                color: Colors.blue,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              const Center(child: Text("Walk more to regenerate energy!", style: TextStyle(fontSize: 12, color: Colors.grey))),
              const Spacer(),
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _showZoneSelector(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                        child: const Column(children: [
                          Icon(Icons.map, color: Color(0xFFEAB308)),
                          SizedBox(height: 8),
                          Text("World Map")
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showShop(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                        child: const Column(children: [
                          Icon(Icons.store, color: Colors.blue),
                          SizedBox(height: 8),
                          Text("Merchant")
                        ]),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- BATTLE SCREEN (UPDATED) ---
class BattleScreen extends StatefulWidget {
  final AppState appState;
  const BattleScreen({super.key, required this.appState});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    // 100ms shake duration
    _shakeController = AnimationController(duration: const Duration(milliseconds: 100), vsync: this);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleAttack() {
    // Play shake animation then reset
    _shakeController.forward().then((_) => _shakeController.reset());
    widget.appState.attackMonster();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Monster Section
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // HP Bar
                    Container(
                      height: 8,
                      width: 100,
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (widget.appState.currentMonsterHp / widget.appState.activeMonster.maxHealth).clamp(0.0, 1.0),
                        child: Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4))),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shake Animation & Image
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final double offset = sin(_shakeController.value * pi * 4) * 10;
                        return Transform.translate(offset: Offset(offset, 0), child: child);
                      },
                      child: Container(
                        height: 250,
                        width: 250,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                           ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            widget.appState.activeMonster.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[900],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.broken_image, color: Colors.red, size: 40),
                                      const SizedBox(height: 8),
                                      Text(widget.appState.activeMonster.name, style: const TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("${widget.appState.activeMonster.name} (Lvl ${widget.appState.user?.level ?? 1})",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
              ),
            ),

            // Console Log
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!)),
              child: SingleChildScrollView(
                reverse: true,
                child: Text("> ${widget.appState.battleLog}",
                    style: const TextStyle(fontFamily: 'Courier', color: Colors.greenAccent)),
              ),
            ),

            // Action Grid
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _handleAttack,
                      icon: const Icon(Icons.flash_on),
                      label: const Text("Attack"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB91C1C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.appState.defendAction(),
                      icon: const Icon(Icons.shield),
                      label: const Text("Defend"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.appState.useSkill(),
                      icon: const Icon(Icons.star),
                      label: const Text("Skill"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA16207),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => widget.appState.usePotion(),
                      icon: const Icon(Icons.local_drink),
                      label: const Text("Potion"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- QUEST SCREEN ---
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
            ...appState.dailyQuests.map((quest) {
              bool isCompleted = steps >= quest.targetSteps;
              bool isClaimed = claimed.contains(quest.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isClaimed ? Colors.green[900]!.withOpacity(0.3) : Theme.of(context).cardTheme.color,
                child: ListTile(
                  leading: Icon(isClaimed ? Icons.check_circle : (isCompleted ? Icons.stars : Icons.circle_outlined),
                      color: isClaimed ? Colors.green : (isCompleted ? Colors.amber : Colors.grey)),
                  title: Text(quest.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(quest.description),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                        value: (steps / quest.targetSteps).clamp(0.0, 1.0),
                        backgroundColor: Colors.black26,
                        color: isCompleted ? Colors.green : Colors.blue,
                        minHeight: 6)
                  ]),
                  trailing: isClaimed
                      ? const Text("DONE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                      : ElevatedButton(
                          onPressed: isCompleted ? () => appState.claimQuest(quest) : null,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: isCompleted ? Colors.amber : Colors.grey[800], foregroundColor: Colors.black),
                          child: Text(isCompleted ? "CLAIM" : "${quest.rewardGold} G")),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- GUILD SCREEN ---
class GuildScreen extends StatelessWidget {
  final AppState appState;
  const GuildScreen({super.key, required this.appState});

  void _showLeaderboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<GuildModel>>(
        future: appState.getLeaderboard(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const AlertDialog(content: LinearProgressIndicator());
          final guilds = snapshot.data!;
          return AlertDialog(
            title: const Text("🏆 Top Guilds"),
            content: SizedBox(
              width: double.maxFinite,
              child: guilds.isEmpty
                  ? const Text("No guilds found.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: guilds.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0 ? Colors.amber : Colors.grey[800],
                          foregroundColor: i == 0 ? Colors.black : Colors.white,
                          child: Text("#${i + 1}"),
                        ),
                        title: Text(guilds[i].name),
                        trailing: Text("${guilds[i].totalSteps} 👣"),
                      ),
                    ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
          );
        },
      ),
    );
  }

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
              Text("No Guild", style: Theme.of(context).textTheme.displaySmall),
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
              TextButton(onPressed: () => _showJoinDialog(context), child: const Text("Join Existing Guild"))
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
            const Center(child: Icon(Icons.shield_moon, size: 60, color: Colors.blue)),
            const SizedBox(height: 10),
            Center(child: Text(guild.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            const Center(child: Text("Guild Level 1", style: TextStyle(color: Colors.blue))),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showLeaderboard(context),
                icon: const Icon(Icons.leaderboard),
                label: const Text("Global Leaderboard"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              ),
            ),
            const SizedBox(height: 20),
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
                    onPressed: () => appState.leaveGuild(), child: const Text("Leave Guild", style: TextStyle(color: Colors.red)))
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: guild.members.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: CircleAvatar(child: Text("${i + 1}")),
                  title: Text(guild.members[i] == appState.user?.uid
                      ? "You"
                      : "Member ID: ${guild.members[i].substring(0, 5)}..."),
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

// --- PROFILE SCREEN ---
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
                child: const Icon(Icons.person, size: 50, color: Colors.grey)),
            const SizedBox(height: 16),
            Text(user.heroName, style: Theme.of(context).textTheme.headlineMedium),
            Text("Level ${user.level} ${user.heroClass}", style: const TextStyle(color: Color(0xFFEAB308))),
            const SizedBox(height: 8),
            SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                    value: user.xp / user.xpToNextLevel,
                    backgroundColor: Colors.grey[800],
                    color: Colors.purpleAccent,
                    minHeight: 10)),
            Text("${user.xp} / ${user.xpToNextLevel} XP", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            
            // --- LIFETIME STEPS CARD ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!)
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Lifetime Steps", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text("${user.lifetimeSteps}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),
            Align(alignment: Alignment.centerLeft, child: Text("Inventory", style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 8),
            Expanded(
              child: user.inventory.isEmpty
                  ? const Center(
                      child: Text("Inventory is empty. Fight monsters to find loot!", style: TextStyle(color: Colors.grey)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: user.inventory.length,
                      itemBuilder: (ctx, i) {
                        final itemId = user.inventory[i];
                        final item = appState.gameItems.firstWhere((it) => it.id == itemId,
                            orElse: () => Item('unknown', '?', '❓', 'Common'));
                        return Container(
                          decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[800]!)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(item.icon, style: const TextStyle(fontSize: 24)),
                            Text(item.name,
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 8), maxLines: 2)
                          ]),
                        );
                      },
                    ),
            ),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: appState.logout, child: const Text("LOGOUT")))
          ],
        ),
      ),
    );
  }
}