# PSD Hub (Plez Script Development) 🚀

[![Language](https://img.shields.io/badge/Language-Luau-00A2FF.svg)](https://luau-lang.org/)
[![Platform](https://img.shields.io/badge/Platform-Roblox-red.svg)](https://www.roblox.com/)
[![License](https://img.shields.io/badge/License-Proprietary-yellow.svg)]()
[![Status](https://img.shields.io/badge/Status-Active-brightgreen.svg)]()

A high-performance, lightweight, modular Roblox executor script hub built with **PlezUI** (pure zero-dependency native UI) and full Luau VM protection.

---

## ⚡ Quick Start / Script Execution

Copy and paste the following loadstring into your executor (e.g. **Madium**, **Potassium**, **Wave**, etc.):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Supanat-hub/plez_hub_release/main/loader.lua"))()
```

### Alternative Direct Load
If you want to bypass the loader and directly run the protected payload:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Supanat-hub/plez_hub_release/main/plez_hub.lua"))()
```

---

## 🎮 Supported Games

| Game | Place ID | Features |
| :--- | :--- | :--- |
| **Ride a Pet** 🐾 | `105578768000572` | Auto Farm, Auto Feed, Auto Upgrades, Anti-AFK, Intelligent Pet Priority Ranking, Teleport |
| **The Forge** ⛏️ | `76558904092080` (World 1)<br>`129009554587176` (World 2)<br>`131884594917121` (World 3) | Auto Mine, Auto Combat, Auto Sell, Ore Filter, Underground Safe Travel |
| **Hypershot** 🎯 | `17516596118` | Smooth Aimlock, FOV Circle, Player Chams Wallhack, Distance/Health ESP, Tracers, Custom FOV, Fullbright |
| **Universal** 🌐 | All Games | WalkSpeed, JumpPower, Noclip, Fly (Mobile & PC), Anti-AFK, Light UI Theme |

---

## ✨ Key Features

- **🚀 PlezUI Native Interface**: Zero third-party dependencies. Ultra-low GPU/memory consumption optimized for mobile and low-end devices.
- **🛡️ Built-in Protection**: Fully obfuscated Luau VM architecture preventing script tampering and asset extraction.
- **🎯 Hypershot FPS Engine**:
  - **Smooth Aimlock**: Adjustable smoothing (0 = instant snap to 0.9 = legit tracking), FOV circle, Wall check (raycasting), Team check, and Mobile lock button.
  - **Visuals & ESP**: Player Chams (DepthMode AlwaysOnTop), Name & Distance ESP, lerped Health Bar, and Snapline Tracers.
  - **Misc & Tweaks**: Custom Camera FOV (70-120°), Fullbright & Remove Fog, and 3rd Person View unlock.
- **🐾 Ride a Pet Automation**:
  - **Smart Pet Ranking Engine**: Automatically analyzes pet stats (EXP, Age, Weight, Species Tier, $/s multiplier) and prioritizes optimal leveling order.
  - **No-Spam Feeding**: Pre-scans inventory to only feed pets with available food, completely eliminating red error spam.
  - **Plot Upgrades**: Automatic Max upgrade and Step-by-Step upgrade loops.
  - **Anti-AFK System**: Automatic virtual keystrokes every 10 minutes to prevent Roblox 20-minute disconnects.
- **💾 Configuration Management**: Fast UNC-compliant file system save/load (`PSD_Hub/` folder) with Auto-Save capabilities.
- **🌐 Multi-Language Support**: Seamlessly switch between English and Thai directly in the Settings tab.

---

## 📱 Executor Compatibility

Tested and verified on:
- **Madium** (~96% UNC Support)
- **Potassium**
- **Synapse / Wave / Delta / Arceus X**

---

## ⚠️ Disclaimer

This script is provided for educational and private convenience purposes only. Use at your own discretion.

