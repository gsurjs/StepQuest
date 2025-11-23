import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
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
  final int xp; //adding curr xp
  final int xpToNextLevel; //adding xp needed for next level
  final int currentSteps;
  final int maxEnergy;
  final int currentEnergy;
  final int gold;

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
  });

  factory UserModel.mock() {
    return UserModel(
      uid: 'test_user_123',
      email: 'hero@stepquest.app',
      heroName: 'Sir Walker',
      heroClass: 'Warrior',
      currentSteps: 2500,
      gold: 150,
    );
  }
}

// ==========================================
// 2. STATE MANAGEMENT & AUTH
// ==========================================

class AppState extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final StepService _stepService = StepService();
  StreamSubscription? _stepSubscription;
  
  User? _firebaseUser;
  UserModel? _currentUser;

  // [BATTLE NEW] Battle State
  int monsterHp = 100;
  int monsterMaxHp = 100;
  String battleLog = "A wild Goblin appeared!";

  bool get isAuthenticated => _firebaseUser != null;
  UserModel? get user => _currentUser;

  AppState() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      if (user != null) {
        _currentUser = await _dbService.getUser(user.uid);
        if (_currentUser == null) _currentUser = UserModel.mock();
        _initPedometer();
      } else {
        _currentUser = null;
        _stepSubscription?.cancel(); 
      }
      notifyListeners();
    });
  }

  Future<void> _initPedometer() async {
    bool granted = await _stepService.init();
    if (granted) {
      _stepSubscription = _stepService.stepStream.listen((stepEvent) {
          // Note: Pedometer sends cumulative steps. 
          // For this MVP simulation, we rely on manual updates via the button
          // to prevent overwriting our "spent" steps logic.
      });
    }
  }

  // [DEV TOOL] Manual Step Increment
  void debugAddSteps(int amount) {
    if (_currentUser != null) {
      _updateUserData(steps: _currentUser!.currentSteps + amount);
    }
  }

   // [PERSISTENCE] Helper to update user state AND save to DB
  void _updateUserData({int? steps, int? gold, int? xp, int? level, int? nextXp}) {
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
      );
      notifyListeners();
      
      // [CRITICAL] Save to Firestore!
      _dbService.createUser(_currentUser!);
     }
  }


  // [GAME LOGIC] Attack Monster
  Future<void> attackMonster() async {
    if (_currentUser == null) return;
    const int cost = 100; // Cost in Steps

    if (_currentUser!.currentSteps < cost) {
      battleLog = "Need $cost steps! Walk more.";
      notifyListeners();
      return;
    }

    // 1. Deduct Steps (Spend them like currency)
    int newSteps = _currentUser!.currentSteps - cost;
    
    // 2. Deal Damage
    int damage = Random().nextInt(15) + 10;
    monsterHp -= damage;
    battleLog = "Attack ($cost steps) dealt $damage DMG!";

    int newGold = _currentUser!.gold;
    int newXp = _currentUser!.xp;
    int newLevel = _currentUser!.level;
    int newNextXp = _currentUser!.xpToNextLevel;

    // 3. Check Win Condition
    // Victory
    if (monsterHp <= 0) {
      monsterHp = 100;
      int goldReward = Random().nextInt(30) + 10;
      int xpReward = Random().nextInt(40) + 20;
      
      newGold += goldReward;
      newXp += xpReward;
      battleLog = "Victory! +$goldReward G, +$xpReward XP";

      // [LEVEL UP LOGIC]
      if (newXp >= newNextXp) {
        newLevel++;
        newXp = newXp - newNextXp; // Rollover XP
        newNextXp = (newNextXp * 1.5).toInt(); // Harder to level up next time
        battleLog += "\n🎉 LEVEL UP! You are now Lvl $newLevel!";
      }
    }

    _updateUserData(
      steps: newSteps, 
      gold: newGold, 
      xp: newXp, 
      level: newLevel, 
      nextXp: newNextXp
    );
  }

  // [GAME LOGIC] Defend
  Future<void> defendAction() async {
    if (_currentUser == null) return;
    const int cost = 50; 
    if (_currentUser!.currentSteps < cost) {
      battleLog = "Need $cost steps to Defend.";
      notifyListeners();
      return;
    }
    battleLog = "Defend ($cost steps) - Blocked attack!";
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
  );
}

// ==========================================
// 4. MAIN APP ENTRY POINT
// ==========================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase Error: $e");
  }
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
          home: _appState.isAuthenticated 
              ? MainScaffold(appState: _appState) 
              : LoginScreen(appState: _appState),
        );
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
  bool _isLoading = false;
  bool _isLogin = true; 
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await widget.appState.login(_emailController.text.trim(), _passwordController.text.trim());
      } else {
        await widget.appState.register(_emailController.text.trim(), _passwordController.text.trim());
      }
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

// --- MAIN SCAFFOLD ---
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
    // [FIXED] Screens are defined inside build() so they update correctly
    final List<Widget> screens = [
      DashboardScreen(appState: widget.appState),
      BattleScreen(appState: widget.appState), // [NEW]
      QuestScreen(appState: widget.appState),  // [NEW]
      GuildScreen(appState: widget.appState),  // [NEW]
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

// --- DASHBOARD SCREEN ---
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

// --- BATTLE SCREEN ---
class BattleScreen extends StatelessWidget {
  final AppState appState;
  const BattleScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // 1. The Scene
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(bottom: BorderSide(color: Colors.grey[800]!, width: 4)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 40,
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        children: [
                          Text("Forest Goblin", style: TextStyle(color: Colors.red[300], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: appState.monsterHp / appState.monsterMaxHp,
                            color: Colors.red,
                            backgroundColor: Colors.red[900],
                            minHeight: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Text("👺", style: TextStyle(fontSize: 100)),
                ],
              ),
            ),
          ),

          // 2. Controls
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

// --- QUEST SCREEN ---
class QuestScreen extends StatelessWidget {
  final AppState appState;
  const QuestScreen({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    final steps = appState.user?.currentSteps ?? 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Quest Board", style: Theme.of(context).textTheme.displayLarge),
            const Text("Quests utilize your current step count!", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildQuestCard(context, "Warm Up", "Reach 1,000 steps", "50 G", steps >= 1000),
            _buildQuestCard(context, "Daily Goal", "Reach 5,000 steps", "100 G", steps >= 5000),
            _buildQuestCard(context, "Marathon", "Reach 10,000 steps", "500 G", steps >= 10000),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(BuildContext context, String title, String desc, String reward, bool completed) {
    return Card(
      color: completed ? Colors.green[900]!.withOpacity(0.3) : null,
      child: ListTile(
        leading: Icon(completed ? Icons.check_circle : Icons.circle_outlined, color: completed ? Colors.green : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: Chip(label: Text(reward), backgroundColor: Colors.amber[800]),
      ),
    );
  }
}

// --- GUILD SCREEN ---
class GuildScreen extends StatelessWidget {
  final AppState appState;
  const GuildScreen({super.key, required this.appState});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(child: Text("Guilds Coming in Week 3!")), // Placeholder for now
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
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(user.heroName, style: Theme.of(context).textTheme.headlineMedium),
            Text("Level ${user.level} ${user.heroClass}", style: const TextStyle(color: Color(0xFFEAB308))),
            
            // [NEW] XP Bar
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: user.xp / user.xpToNextLevel,
                backgroundColor: Colors.grey[800],
                color: Colors.purpleAccent,
                minHeight: 10,
              ),
            ),
            Text("${user.xp} / ${user.xpToNextLevel} XP", style: const TextStyle(fontSize: 12, color: Colors.grey)),

            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(context, "Strength", "24"),
                  _buildStatCard(context, "Agility", "18"),
                  _buildStatCard(context, "Total Steps", "${user.currentSteps}"),
                  _buildStatCard(context, "Gold", "${user.gold}"),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: appState.logout,
                child: const Text("LOGOUT"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}