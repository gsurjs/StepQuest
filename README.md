# ⚔️ StepQuest - Fitness RPG
## Turn your walk into an Adventure.

StepQuest is a gamified fitness application built with Flutter and Firebase that transforms daily physical activity into an engaging RPG experience. By syncing with the device's pedometer, every step you take in the real world powers your hero's journey, fuels battles against monsters, and earns legendary loot.

## 🚀 Features
* **Core Mechanics:** 
    * **👣 Real-Time Step Tracking:** Integrates with device sensors (Pedometer) to count steps live.
    * **🔋 Energy System:** Steps convert into "Energy" needed to perform actions in the game.
    * **⚔️ Battle System:** Use your step-energy to attack monsters. Deal damage, gain XP, and earn Gold.
    * **📈 Character Progression:** Level up your hero to increase stats. XP bar resets and scales with each level.

* **World & Economy**
    * **🌍 World Zones:** Travel between 3 distinct biomes (Whispering Woods, Stonekeep Caves, Molten Core) as you level up.
    * **💰 The Merchant:** Earn Gold from battles and visit the shop to buy equipment like Wooden Swords, Iron Shields, and the legendary Ring of Power.
    * **🎒 Inventory Management:** Equip items to boost your stats and manage your loot.

* **Social & Engagement**
    * **🛡️ Guild System:** Create or Join guilds. Contribute your steps to the guild's total score.
    * **🏆 Global Leaderboard:** Compete against other guilds to see who walks the most.
    * **📜 Daily Quests:** Complete challenges like "Walk 5,000 Steps" to earn bonus rewards. Quests reset daily.
    * **💼 Loot:** Chance to find items (Swords, Potions) after winning battles.

## 🛠️ Tech Stack

**Frontend:** Flutter (Dart)
**Backend:** Firebase (Firestore, Authentication)
**State Management:** ChangeNotifier / Provider pattern
**Device Integration:** pedometer, permission_handler

## 🔧 Installation & Setup

* **Prerequisites**
    * Flutter SDK
    * Android Studio / VS Code IDE
    * A Firebase Project

* **Steps to Run**
    * Clone The Repo
    * Install Dependencies with cli command "flutter pub get"
    * Create & Configure Firebase 
    * Run The App with cli command "flutter run"

## 🧪 Testing w/ Simulator
 
 Since emulators lack physical sensors, the app includes a **Developer Mode**

 To unlock this mode, go to the **Hub** screen, Tap 7 times within 2 seconds on the **Daily Steps Green Circle** in the middle of the screen, and this will unlock the **"Simulate 500 Steps"** button. This button manually increments your step count to test the Battle and Quest logic without walking.