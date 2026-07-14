SonicVision.swiftpm/
│
├── App/
│   └── SonicVisionApp.swift              # Entry point
│
├── Views/
│   ├── MainView.swift                    # Container principal
│   ├── ARCameraView.swift                # ARKit UIViewRepresentable
│   ├── ControlPanelView.swift            # Toggle + Intensity slider
│   └── Components/
│       ├── LiquidGlassCard.swift         # Design system
│       └── AccessibilityBadge.swift      # Disclaimers
│
├── ViewModels/
│   └── SonicViewModel.swift              # État central + coordination
│
├── Services/
│   ├── ARSessionManager.swift            # LiDAR + ARFrame processing
│   ├── HapticEngine.swift                # Core Haptics patterns
│   ├── SpatialAudioEngine.swift          # AVAudioEngine 3D
│   └── VisionDetector.swift              # Vision offline detection
│
├── Models/
│   ├── DepthFrame.swift                  # Structure de données depth
│   ├── DetectedObject.swift              # Résultat Vision
│   └── HapticPattern.swift               # Descripteur de pattern
│
└── Resources/
    └── Sounds/
        └── ping.wav                       # Son de base (généré en code si besoin)