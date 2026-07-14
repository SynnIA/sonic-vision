# Sonic Vision
**Multi-Sensory Spatial Awareness for Everyone**

Sonic Vision transforms LiDAR depth data into intuitive haptic and audio feedback, creating a complementary spatial awareness tool. Point your iPad Pro at the world and *feel* and *hear* the space around you.

## Technical Stack

| Technology | Purpose |
|---|---|
| **ARKit** | LiDAR depth scanning (`sceneDepth`) at 10 Hz |
| **Core Haptics** | Progressive vibration patterns (iPhone) |
| **AVAudioEngine** | 3D spatial audio with HRTF rendering |
| **Vision** | On-device object detection (30+ categories) |
| **SwiftUI** | Accessible, adaptive interface with Liquid Glass design |

## Key Features

- **100% offline, privacy-first** — zero data collection, all processing on-device
- **Real-time depth to multi-sensory feedback** — LiDAR depth mapped to haptics + spatial audio
- **3D spatial audio positioning** — HRTF rendering places sounds in 3D space around the listener
- **Object recognition** — detects people, furniture, vehicles, obstacles using Vision framework
- **Animated sonar overlay** — concentric pulse waves visualize LiDAR scanning in real-time
- **Design system** — San Francisco Rounded typography, Liquid Glass materials, spring animations
- **iPad Pro optimized** — built for LiDAR hardware, graceful fallback without it

## Architecture

MVVM + Services pattern with Combine data flow:

```
ARSessionManager ──► currentDepthFrame ──► SonicViewModel ──► HapticEngine
        │                                        │              SpatialAudioEngine
        └──────► currentPixelBuffer ──► VisionDetector ──► detectedObjects ──► UI Overlay
```

### Services

| Service | Responsibility |
|---|---|
| `ARSessionManager` | LiDAR depth capture, 10 Hz processing, simulation fallback |
| `HapticEngine` | Core Haptics lifecycle, pattern playback with user intensity scaling |
| `SpatialAudioEngine` | AVAudioEngine + HRTF 3D, sine ping cache (400/800/1200 Hz) |
| `VisionDetector` | VNClassifyImageRequest + VNDetectHumanRectanglesRequest + VNDetectRectanglesRequest |

### Design System

| Token | Usage |
|---|---|
| `Typo.*` | San Francisco Rounded scale (display 48pt to tag 10pt) |
| `Space.*` | Consistent spacing (xs 4pt to xxl 32pt) |
| `Radius.*` | Corner radii hierarchy (panel 24pt, card 16pt, button 14pt) |
| `Anim.*` | Spring physics, transitions, interactive scales |

## Visual Design

- **Liquid Glass** — `.ultraThinMaterial` translucency throughout, zero opaque backgrounds
- **Sonar Overlay** — 3 concentric animated waves, color-coded by proximity (red/orange/cyan)
- **Detection Pills** — floating capsules with urgency colors for detected objects
- **Motion** — spring physics on all interactions, staggered animations

## Hardware Requirements

- **iPad Pro** (2020+) with LiDAR scanner — required for depth sensing
- **iPhone 12 Pro+** — for full haptic experience
- **Headphones recommended** — for spatial audio positioning (AirPods Pro ideal)

## Stats

- **1,862 LOC** across 16 Swift files
- **Zero external dependencies** — pure Apple frameworks
- **< 1 MB** source code
- **iOS 17.0+** minimum deployment target

## Important Disclaimers

**Not a medical device** — Sonic Vision is an experimental complementary tool. It has not been evaluated or approved by any medical or regulatory authority.

**Does not replace:**
- A white cane or mobility aid
- A guide dog
- Orientation & mobility training
- Professional accessibility assessments
- Any established assistive technology

**Privacy:** All processing happens entirely on-device. No camera data, depth information, or usage data is ever transmitted, stored, or shared.

---

*Swift Student Challenge 2026*
*Built with Swift, ARKit, and passion for accessibility*
