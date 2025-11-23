# ⚔️ StepQuest - Fitness RPG
## Turn your walk into an Adventure.

StepQuest is a gamified fitness application built with Flutter and Firebase that transforms daily physical activity into an engaging RPG experience. By syncing with the device's pedometer, every step you take in the real world powers your hero's journey, fuels battles against monsters, and earns legendary loot.

## 🚀 Features
* **Core Mechanics:** 
    * **👣 Real-Time Step Tracking:** Integrates with device sensors (Pedometer) to count steps live.
    * **🔋 Energy System:** Steps convert into "Energy" needed to perform actions in the game.
    * **⚔️ Battle System:** Use your step-energy to attack monsters. Deal damage, gain XP, and earn Gold.
    * **📈 Character Progression:** Level up your hero to increase stats. XP bar resets and scales with each level.

* **Social & Engagement**
    * **🛡️ Guild System:** Create or Join guilds. Contribute your steps to the guild's total score.
    * **🏆 Global Leaderboard:** Compete against other guilds to see who walks the most.
    * **📜 Daily Quests:** Complete challenges like "Walk 5,000 Steps" to earn bonus rewards. Quests reset daily.
    * **🎒 Inventory & Loot:** Chance to find items (Swords, Potions) after winning battles.

## 🛠️ Tech Stack

**Frontend:** Flutter (Dart)
**Backend:** Firebase (Firestore, Authentication)
**State Management:** ChangeNotifier / Provider pattern
**Device Integration:** pedometer, permission_handler