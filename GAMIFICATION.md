# Gamification Features Added to MonuAI

## Overview
A comprehensive gamification system has been integrated into the landmark detection app, inspired by modern learning apps with points, streaks, levels, achievements, leaderboard, and daily rewards.

## Features Implemented

### 1. **Points & Leveling System**
- **Points earned for**:
  - Discovering a new landmark: **+50 points**
  - Uploading a photo: **+25 points**
  - Daily streak bonus: **+10 points per day**
  - Fortune wheel spin: **+5 to +200 points**
  - Achievement unlocks: **+50 to +500 bonus points**
- **Level progression**: Every 100 points = 1 level up
- Visual progress bar showing XP to next level

### 2. **Streak System**
- Tracks daily app usage
- Consecutive days build up current streak
- Records longest streak achieved
- Visual fire icon with streak count on home screen
- Automatic daily check-in when app opens

### 3. **Achievement System**
Built-in achievements include:
- 🎯 **First Steps** - Discover your first landmark (+50 pts)
- 🗺️ **Explorer** - Visit 5 different landmarks (+100 pts)
- 🌍 **World Traveler** - Visit 10 different landmarks (+200 pts)
- 📸 **Photographer** - Upload 5 photos (+100 pts)
- 🔥 **On Fire!** - Maintain a 3-day streak (+75 pts)
- ⚡ **Committed** - Maintain a 7-day streak (+150 pts)
- ⭐ **Rising Star** - Reach level 5 (+250 pts)
- 👑 **Legend** - Reach level 10 (+500 pts)

### 4. **Leaderboard**
- Beautiful podium-style top 3 display
- Period filters: Today, This week, All time
- Current user highlighted with blue accent
- Ranking list with avatars and points
- Deep blue theme matching reference design
- Tap points card on home screen to view

### 5. **Fortune Wheel**
- Daily reward wheel with 6 segments
- 3 free spins per day (resets at midnight)
- Animated spinning with smooth rotation
- Reward values: 5, 10, 20, 50, 100, 200 points
- Visual spin counter with badge notification
- Glowing circular design with gradient colors
- Accessible via home screen button

### 6. **Enhanced Home Screen**
- Welcome message with user greeting
- Three stat cards displaying:
  - **Points** (gold) - tappable to view leaderboard
  - **Streak** (orange) - fire icon
  - **Level** (purple) - progress badge
- Level progress bar with XP tracking
- Fortune wheel quick access button with spin badge
- All gamification UI at top, scrolls with content

## Technical Implementation

### Data Models
- `UserStats` - Points, level, streaks, achievements, spins
- `Achievement` - ID, title, description, unlock condition
- `FortuneWheelReward` - Label, points, icon, description

### Service Layer
- `GamificationService` - Core logic for:
  - Loading/saving user stats via SharedPreferences
  - Awarding points and handling level-ups
  - Tracking and updating streaks
  - Recording landmark visits and photo uploads
  - Managing fortune wheel spins and daily reset
  - Checking achievement unlock conditions
  - Mock leaderboard data (ready for backend integration)

### UI Components
- `LeaderboardScreen` - Full-screen podium + rankings
- `FortuneWheelScreen` - Interactive spinning wheel
- `_StatsCard` - Reusable stat display widget
- Gamification header integrated into `HomeScreen`

### Integration Points
1. **Scan Screen** - Awards points when new landmarks discovered
2. **Photo Upload** - Awards +25 points on successful upload
3. **Home Screen** - Displays stats, calls streak update on init
4. **Navigation** - Leaderboard and fortune wheel accessible

## Data Persistence
All gamification data stored locally using `SharedPreferences`:
- User stats saved as JSON
- Points, level, streaks, achievements persisted
- Fortune wheel spins and timestamps tracked
- Automatic loading on app start

## Future Enhancements
- Backend API for global leaderboard
- Social features (friends, challenges)
- More achievements (country-specific, time-based)
- Customizable avatars unlocked by level
- Weekly/monthly competitions
- Push notifications for streak reminders
- Reward redemption (badges, themes, power-ups)

## Usage
The gamification system works automatically:
1. Open app → Streak updates, stats load
2. Discover landmarks → Earn points, check achievements
3. Upload photos → Get bonus points
4. Tap fortune wheel → Spin for daily rewards
5. Tap points card → View leaderboard
6. Level up → See progress bar fill

All features are seamlessly integrated into existing workflows!
