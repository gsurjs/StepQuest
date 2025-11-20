import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:step_quest/services/auth_service.dart'; 
import 'package:step_quest/services/database_service.dart';
import 'dart:math';

// ==========================================
// MODELS (Week 1, Days 3-4: Schema)
// ==========================================

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

class AppState extends ChangeNotifier {
  // Initialize our custom AuthService
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  // Track the real Firebase User
  User? _firebaseUser;
  UserModel? _currentUser;

  bool get isAuthenticated => _firebaseUser != null;
  UserModel? get user => _currentUser;

  AppState() {
    _init();
  }

  // Setup the Listener
  // This function runs automatically whenever you log in or log out
  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _firebaseUser = user;
      
      if (user != null) {
        print("✅ Auth Detected. Fetching RPG Stats for: ${user.email}");
        // [3] UPDATED: Fetch REAL data from Firestore
        _currentUser = await _dbService.getUser(user.uid);
        
        // Fallback if DB entry is missing (shouldn't happen if register works)
        if (_currentUser == null) {
           print("⚠️ No DB entry found. Using Mock.");
           _currentUser = UserModel.mock();
        }
      } else {
        print("ℹ️ User is logged out");
        _currentUser = null;
      }
      notifyListeners();
    });
  }


  // Calls authService
  Future<void> login(String email, String password) async {
    await _authService.signIn(email, password);
  }

  // Registration logic
  // Registration now saves to Database
  Future<void> register(String email, String password) async {
    // 1. Create Auth Account
    User? user = await _authService.signUp(email, password);
    
    // Create Firestore Entry (Default Hero)
    if (user != null) {
      UserModel newUser = UserModel(
        uid: user.uid, 
        email: email, 
        heroName: "New Hero", 
        heroClass: "Warrior"
      );
      await _dbService.createUser(newUser);
    }
  }

  Future<void> logout() async {
    await _authService.signOut();
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
// MAIN APP ENTRY POINT
// ==========================================

void main() async {
  // Bindings must be initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    print("✅ Firebase Initialized Successfully");
  } catch (e) {
    print("❌ Firebase Initialization Failed: $e");
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
  
  // Toggle between "Login Mode" and "Register Mode"
  bool _isLogin = true; 
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // [8] UPDATED: The Submit Logic
  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      // If _isLogin is true, we call login(), otherwise we call register()
      if (_isLogin) {
        await widget.appState.login(
          _emailController.text.trim(), 
          _passwordController.text.trim()
        );
      } else {
        await widget.appState.register(
          _emailController.text.trim(), 
          _passwordController.text.trim()
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_walk, size: 80, color: Color(0xFFEAB308)),
                const SizedBox(height: 20),
                Text("StepQuest", style: Theme.of(context).textTheme.displayLarge),
                
                // [9] UI: Change title based on mode
                Text(
                  _isLogin ? "Enter the Tavern" : "Join the Guild", 
                  style: Theme.of(context).textTheme.bodyMedium
                ),
                const SizedBox(height: 48),
                
                TextFormField(
                  controller: _emailController,
                  // [10] UI: Basic Validation
                  validator: (val) => val != null && val.contains('@') ? null : 'Invalid Email',
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  validator: (val) => val != null && val.length > 5 ? null : 'Password too short',
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
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator() 
                      : Text(_isLogin ? "LOGIN" : "REGISTER", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                
                // [11] UI: Button to toggle modes
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
      const Center(child: Text("Battle Arena\n(Coming Week 2)")),
      const Center(child: Text("Quest Board\n(Coming Week 3)")),
      const Center(child: Text("Guild Hall\n(Coming Week 3)")),
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
                      value: user.currentSteps / 10000,
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
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}