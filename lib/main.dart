import 'package:flutter/material.dart';
import 'dart:math';

// ==========================================
// MODELS (Week 1, Days 3-4: Schema)
// ==========================================

/// Represents the player's persistent data.
/// mirrors the Firestore document structure.
class UserModel {
  final String uid;
  final String email;
  final String heroName;
  final String heroClass; // Warrior, Rogue, Mage
  final int level;
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
    this.currentSteps = 0,
    this.maxEnergy = 100,
    this.currentEnergy = 100,
    this.gold = 0,
  });

  // Factory to create a mock user for testing
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
// STATE MANAGEMENT & AUTH (Week 1, Days 1-2)
// ==========================================

/// A simple provider to manage User State and Auth logic.
/// Firebase Auth here.
class AppState extends ChangeNotifier {
  UserModel? _currentUser;
  bool get isAuthenticated => _currentUser != null;
  UserModel? get user => _currentUser;

  // TODO: Week 1 Day 1 - Replace with Firebase Auth signIn
  Future<void> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock successful login
    _currentUser = UserModel.mock();
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // TODO: Week 2 - Connect this to the Pedometer package
  void updateSteps(int steps) {
    if (_currentUser != null) {
      // Logic to update steps would go here
      notifyListeners();
    }
  }
}

// ==========================================
// THEME (Week 1, Days 5-7: UI Foundation)
// ==========================================

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
    primaryColor: const Color(0xFFEAB308), // Yellow 500 (Gold)
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFEAB308),
      secondary: Color(0xFF3B82F6), // Blue 500
      surface: Color(0xFF1E293B), // Slate 800
      error: Color(0xFFEF4444), // Red 500
    ),
    fontFamily: 'Georgia', // Serif for that RPG feel
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEAB308)),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: Color(0xFF94A3B8)), // Slate 400
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ==========================================
// MAIN APP ENTRY POINT
// ==========================================

void main() {
  // TODO: Week 1 Day 1 - Initialize Firebase here
  // await Firebase.initializeApp();
  
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
    // Using an AnimatedBuilder to listen to AppState changes (Simple State Management)
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
// SCREENS
// ==========================================

// --- LOGIN SCREEN (The Tavern) ---
class LoginScreen extends StatefulWidget {
  final AppState appState;
  const LoginScreen({super.key, required this.appState});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await widget.appState.login("test", "test");
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_walk, size: 80, color: Color(0xFFEAB308)),
              const SizedBox(height: 20),
              Text("StepQuest", style: Theme.of(context).textTheme.displayLarge),
              Text("Turn your walk into an adventure.", style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),
              
              // Mock Form
              TextFormField(
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("ENTER THE TAVERN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN SCAFFOLD (Navigation Controller) ---
class MainScaffold extends StatefulWidget {
  final AppState appState;
  const MainScaffold({super.key, required this.appState});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(appState: widget.appState),
      const Center(child: Text("Battle Arena\n(Coming Week 2)")), // Placeholder
      const Center(child: Text("Quest Board\n(Coming Week 3)")),  // Placeholder
      const Center(child: Text("Guild Hall\n(Coming Week 3)")),   // Placeholder
      ProfileScreen(appState: widget.appState),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
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

// --- DASHBOARD SCREEN (World Map) ---
class DashboardScreen extends StatelessWidget {
  final AppState appState;
  const DashboardScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final user = appState.user!;
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Step Circle
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: user.currentSteps / 10000, // Assuming 10k goal
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
            const SizedBox(height: 40),

            // Energy Bar
            const Text("Energy"),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: user.currentEnergy / user.maxEnergy,
              backgroundColor: Theme.of(context).colorScheme.surface,
              color: Colors.blue,
              minHeight: 10,
            ),
            const SizedBox(height: 4),
            Text("${user.currentEnergy}/${user.maxEnergy}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
    final user = appState.user!;
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
            const SizedBox(height: 32),
            
            // Stats Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(context, "Strength", "24"),
                  _buildStatCard(context, "Agility", "18"),
                  _buildStatCard(context, "Total Steps", "145k"),
                  _buildStatCard(context, "Battles", "32"),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}