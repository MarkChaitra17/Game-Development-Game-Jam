
# **<u>Outbreak Survival - Game Design Document</u>** 

Student Name: Mark Chaitra Student ID:100874524 Date: 23/09/2026 

Class: CSCI 4160U Game Development 

Repository Link: <u>https://github.com/MarkChaitra17/Game-Development-Game-Jam</u> 

## **<u>Description</u>** 

**Description:** Top down shooter where player must survive waves of enemy attacks at increasing difficulty. Players must shoot and kill enemies in order to gain points and succeed levels to progress. Enemies walk towards the player to damage their health by coming in direct contact with the player or shooting back at the player. Players can use points to speed up bullets or walking speed, increase bullet damage or add back health if needed. 

## **<u>Core Gameplay Loop</u>** 

**The Gameplay Loop:** Players on the screen can move around the screen while enemies walk towards them possibly shooting back. Players must shoot and kill enemies in order to level up to get upgrades and increase the enemy difficulty with health. 

**Primary Mechanics:** Player shoots enemy, has a bar to track health. 

**Secondary Mechanics:** Enemy spawns and walks towards the player to damage player health. 

**Tertiary Mechanics:** Players can level up walking speed, shooting speed, bullet damage. 

## **<u>MDA Framework</u>** 

### **Mechanics:** 

- Player movement using key controls 

- Player aims and shoots bullets at enemies 

- Enemies spawn in waves and move toward the player 

- Enemies can damage the player through contact or shooting 

- Defeating enemies awards points/experience 

- Players level up by defeating enemies 

- Level-ups allow players to upgrade movement speed, shooting speed, bullet speed, bullet damage, and health 

- Enemy health and difficulty increase as the player increases levels 

- The player loses when their health reaches zero 

### **Dynamics:** 

- Players constantly move and reposition to avoid enemy attacks 

- Players prioritize which enemies to attack based on distance 

- Increasing enemy numbers create pressure and force players to make quick decisions 

- Players balance attacking enemies with avoiding damage 

- Players must make decisions to attack or run away from enemies to save health 

### **Aesthetics:** 

- **Challenge:** Increasing enemy difficulty tests the player's reaction time and decision-making. 

- **Tension:** Large enemy waves and limited health create pressure as the player tries to survive. 

## **<u>Player Experience</u>** 

### **How should they feel? (Incorporate Leblanc’s Taxonomy of pleasures):** 

- **Challenge:** Players should feel challenged by increasing enemy numbers, health status, and attack patterns 

- **Sensation:** Players should feel excitement and intensity from fast-paced shooting, enemy attacks, and visual/audio feedback when enemies are defeated. 

- **Fantasy:** Players should feel like a powerful survivor fighting through overwhelming enemy forces. 

### **Game Inspirations:** 

- GTA 

### **Non-Game Inspirations:** 

- Zombie/Horde scenarios such as The Walking Dead 

### **Genre:** 

Top down Shooter / survival 

### **Target Audience (Incorporate Bartle’s Taxonomy):** 

- **Killers:** Players who enjoy fast-paced combat, defeating large numbers of enemies, and achieving high scores. 

### **Progression Over Time:** 

Players start with basic weapons and starter abilities. Overtime, abilities such as walking speed, bullet speed, and health total can be upgraded as enemies become more difficult. 

### **Themes:** 

- Survival against the odds 

- Growth and becoming stronger 

- Adaptation and strategy 

### **Platform & Tools:** 

- Odin and raylib 

- AI tools (Claude, Gemini, Chatgpt) 

- VScode 

### **Anything else unusual that needs explaining (if applicable):** 

