<div align="center">

# 🏛️ MonuAI

**AI-Powered Landmark Detection & Gamification App**

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow_Lite-GPU-FF6F00?logo=tensorflow)](https://www.tensorflow.org/lite)
[![YOLOv11](https://img.shields.io/badge/YOLOv11-Nano-00FFFF)](https://github.com/ultralytics/ultralytics)

*Discover landmarks, earn rewards, and compete with friends!*

</div>

---

## 📱 About

**MonuAI** is a gamified landmark detection application that combines computer vision with an engaging reward system. Scan landmarks in real-time using your camera, and watch as the AI identifies them instantly. Collect points, level up with XP, spin the fortune wheel, and climb the leaderboard!

### ✨ Key Features

- 🎯 **Real-Time Detection** - YOLOv11 nano model with GPU acceleration
- 📸 **Smart Capture** - Auto-saves original photos, predicts on-demand
- 🎮 **Gamification System** - Points, XP, levels, and achievements
- 🎡 **Fortune Wheel** - Spin to win bonus points (50-200)
- 🏆 **Leaderboard** - Compete with mock users based on levels
- 🎖️ **Achievements** - Track progress across multiple challenges
- 🌐 **Landscape Mode** - Full-screen detection experience

---

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Android device or emulator (API 21+)
- Android Studio or VS Code with Flutter extension

### Installation

```powershell
# Clone the repository
git clone https://github.com/AnJayAx/monuai.git
cd monuai

# Clean and install dependencies
flutter clean
flutter pub get

# Run the app
flutter run
```

---

## 🛠️ Development Commands

### Basic Commands

```powershell
# Check Flutter environment
flutter doctor -v

# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run in debug mode
flutter run

# Build APK
flutter build apk --release
```

### 🔧 ADB Troubleshooting

If the app fails to install or launch:

```powershell
# Restart ADB server
adb kill-server
adb start-server
adb devices

# Navigate to project directory
cd "d:\SIT\AAI3001 Computer Vision\Project\monuai"

# Install/Replace APK manually
adb install -r -t "build\app\outputs\flutter-apk\app-debug.apk"

# Launch the app
adb shell am start -n com.example.monuai/com.example.monuai.MainActivity

# Or upgrade Flutter and attach
flutter upgrade
flutter attach
```

---

## 🐛 Android Troubleshooting

### Gradle Import Errors

If VS Code shows errors like **"phased build action failed"** or cannot create tasks for `camera_android_camerax`:

#### Root Causes
1. Errors originate from Java/Gradle import (Red Hat Java extension), not Flutter
2. Multi-drive layout (project on `D:`, Pub cache on `C:`) confuses Gradle

#### Solutions

**Option 1: Disable Gradle Import** (Recommended)
- Already configured in `.vscode/settings.json`
- Ignore VS Code Java Problems panel if build succeeds

**Option 2: Fix Multi-Drive Issues**
```powershell
# Move project to C: drive OR set PUB_CACHE to D: drive
set PUB_CACHE=D:\path\to\pub-cache
flutter pub cache repair
```

**Option 3: Gradle Configuration**
- Added in `android/gradle.properties`:
  ```properties
  org.gradle.configuration-cache=false
  org.gradle.parallel=false
  ```

**Option 4: Downgrade Gradle**
```powershell
# Check recommended version
flutter doctor

# Edit android/gradle/wrapper/gradle-wrapper.properties
# Update distributionUrl to recommended version
```

### Verify Build

```powershell
flutter clean
flutter pub get
flutter doctor -v
flutter run
```

✅ If the app builds and runs successfully, ignore IDE warnings!

---

## 🎮 Gamification System

### 📊 Rewards Structure

| Action | Points | XP | Spins |
|--------|--------|----|----|
| Detect Landmark | +5 | +2 | +1 |

### 🎡 Fortune Wheel Rewards

- 🟢 50 Points
- 🔵 75 Points  
- 🟡 100 Points
- 🟠 125 Points
- 🟣 150 Points
- 🔴 200 Points

### 📈 Level System

- **2 XP** per landmark detected
- **10 XP** per level (level 1 = 10 XP, level 2 = 20 XP, etc.)
- Leaderboard ranks by **level** first, then XP

### 🏅 Achievements

Track your progress across multiple challenge categories:
- First Steps
- Explorer
- Dedicated Visitor
- And many more!

---

## 🤖 AI Model

- **Architecture**: YOLOv11 Nano
- **Input Size**: 640x640
- **Format**: FP32 TensorFlow Lite
- **Acceleration**: GPU Delegate V2
- **Classes**: 4 landmarks (customizable via `assets/labels.txt`)
- **Performance**: Frame stride of 15 for optimal speed

---

## 📁 Project Structure

```
monuai/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── models/
│   │   └── gamification_models.dart # Data models
│   ├── screens/
│   │   ├── scan_screen.dart         # Real-time detection
│   │   ├── landmark_photo_screen.dart # On-demand prediction
│   │   ├── home_screen.dart         # Dashboard
│   │   ├── leaderboard_screen.dart  # Rankings
│   │   ├── fortune_wheel_screen.dart # Spin rewards
│   │   └── achievements_screen.dart  # Progress tracking
│   └── services/
│       └── gamification_service.dart # Core game logic
├── assets/
│   ├── models/
│   │   └── model_fp32_student.tflite # YOLOv11 model
│   ├── labels.txt                   # Landmark classes
│   └── landmark_descriptions.json   # Info text
└── android/                         # Android configuration
```

---

## 🎨 Features in Detail

### 🔍 Detection Flow

1. **Scan Screen** (Landscape, Full-Screen)
   - Real-time camera preview with GPU-accelerated inference
   - Processes every 15th frame for optimal performance
   - Shows landmark descriptions with smart collision detection
   - Auto-captures original photo (no bounding box)

2. **Photo Screen** (On-Demand Prediction)
   - Loads TFLite model with GPU acceleration
   - Runs inference on original photo
   - Draws bounding box with confidence score
   - Shows loading indicator during prediction
   - Auto-confirms landmark discovery

### 🎯 Smart Positioning

Descriptions intelligently position themselves to avoid:
- ✅ Overlapping with bounding boxes
- ✅ Going outside screen boundaries
- ✅ Colliding with other descriptions

6 position attempts: right → left → below → above → right-bottom → left-bottom

---

## 📄 License

This project is part of the **AAI3001 Computer Vision** course at SIT.

---

## 👥 Contributors

- **AnJayAx** - Developer & Maintainer

---

<div align="center">

**Built with ❤️ using Flutter & TensorFlow Lite**

[Report Bug](https://github.com/AnJayAx/monuai/issues) • [Request Feature](https://github.com/AnJayAx/monuai/issues)

</div>