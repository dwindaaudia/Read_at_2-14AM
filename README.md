# Read at 2:14 AM

> An interactive psychological thriller mobile game for iOS, built entirely inside a chat interface. Every choice you make shifts the story — and your perception of it.

---

## 👥 Team

| Name | Role | GitHub |
|------|------|--------|
| Joshua | Domain Expert | [@itreestudio](https://github.com/itreestudio) |
| Dwinda | Tech | [@dwindaaudia](https://github.com/dwindaaudia) |
| Stefanie | Tech | [@stfnghr](https://github.com/stfnghr) |
| Steve | Tech | [@Stevefit](https://github.com/Stevefit) |
| Nicole | Design | [@nicolecole-3](https://github.com/nicolecole-3) |

---

## 🛠️ Tech Stack

- **Platform:** iOS 18+
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Game Layer:** SpriteKit (glitch & audio layer)
- **State Machine:** GameplayKit — GKStateMachine
- **AI Dialogue:** Apple FoundationModels (on-device, Apple Intelligence)
- **Haptics:** UIKit
- **IDE:** Xcode
- **Version Control:** Git + GitHub

---

## 🎮 Gameplay

All interaction happens inside a simulated chat screen. The player receives messages from a character named **Alex** and responds via three choices:

- **Trust**
- **Denial**
- **Avoidance**

Each choice shifts an integer **Denial Score**, which determines the **Denial Level** (Low / Medium / High). The Denial Level controls nearly all runtime output:

- Number of chat bubbles from Alex
- Tone and content of messages
- Version of media assets sent (photo, voice note, video)
- Audio ambience intensity
- Glitch visual intensity
- Haptic feedback pattern

There is no conventional UI — all gameplay happens inside chat bubbles and response choices.

---

## 📖 Chapter 1 — Scene Overview

| Scene | Name | Type |
|-------|------|------|
| S1 | Lockscreen Intro | Hardcoded |
| S2 | First Contact | Foundation Model |
| S3 | Photo Event | Foundation Model |
| S4 | Guilt Build | Hardcoded + Glitch |
| S5 | Voice Reveal | Foundation Model |
| S6 | Final Hook | Hardcoded |

---

## ⚙️ Dialogue Generation Modes

| Mode | Description |
|------|-------------|
| **Hardcoded** | Fixed dialogue, fully scripted |
| **Foundation Model** | Dynamic, on-device via Apple Intelligence |
| **Fallback** | Static backup if Foundation Model unavailable |

---

## 📁 Project Structure


```
Read_at_2-14AM/
├── Models/
│   ├── GameManager.swift        # State machine, generation logic, view model
│   ├── HardcodedDialogue.swift  # Backup dialogue (3 scenes × 3 paths × 3 denial levels)
│   └── DenialScoreSystem.swift  # Denial score & level logic
├── Views/
│   ├── LockScreenView.swift
│   ├── ChatRoomView.swift
│   ├── MessageBubble.swift
│   ├── ChoiceKeyboardView.swift
│   └── GlitchLayer.swift
├── Resources/
│   ├── Audio/
│   └── Assets.xcassets/
├── .gitignore
├── CONTRIBUTING.md
└── README.md
```

---

## 🚀 Getting Started

1. Clone this repository
2. Open `Read_at_2-14AM.xcodeproj` in Xcode
3. Make sure your device supports **iOS 18+** and **Apple Intelligence**
4. Use a physical device (Apple Intelligence is not available on simulator)
5. Press **Run (⌘R)**

---

## 📋 Project Status

- [ ] Repo setup & branching
- [ ] Game Manager & state machine
- [ ] Denial Score system
- [ ] Chat UI (ChatRoomView, MessageBubble, ChoiceKeyboard)
- [ ] S1 — Lockscreen Intro
- [ ] S2 — First Contact
- [ ] S3 — Photo Event
- [ ] S4 — Guilt Build
- [ ] S5 — Voice Reveal
- [ ] S6 — Final Hook
- [ ] Glitch layer & haptic feedback
- [ ] Audio system
- [ ] Foundation Model integration
- [ ] Playtesting & polish
- [ ] Submission

---

## 📄 License

This project was created for Apple Developer Academy.
