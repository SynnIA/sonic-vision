# SONIC VISION — Dossier Technique de Construction

## 🎯 Objectif de ce document
Ce fichier sert de **référence unique** pour construire le projet Sonic Vision.
Il doit être placé à la racine du projet et utilisé comme contexte par Claude Code.

---

## 1. Identité du projet

| Clé | Valeur |
|---|---|
| **Nom** | Sonic Vision |
| **Type** | Swift Playground App (.swiftpm) |
| **Cible** | iPad Pro avec LiDAR |
| **IDE** | Swift Playgrounds 4.x sur iPad |
| **UI** | SwiftUI (iOS 18+, Liquid Glass si iOS 26) |
| **Taille max** | 25 MB total |
| **Réseau** | 100% Offline — aucun appel réseau |
| **Langage** | Swift 5.9+ |

---

## 2. Frameworks Apple utilisés

| Framework | Usage | Offline |
|---|---|---|
| **ARKit** | Session AR + sceneDepth (LiDAR) | ✅ |
| **CoreHaptics** | Vibrations dynamiques continues | ✅ |
| **AVFoundation** | Audio spatial + AVSpeechSynthesizer | ✅ |
| **Vision** | VNClassifyImageRequest / VNRecognizeAnimalsRequest | ✅ |
| **SwiftUI** | Interface complète | ✅ |
| **Combine** | Bindings réactifs (si nécessaire) | ✅ |

> **Pas de CoreML custom** dans le MVP. On utilise les modèles Vision embarqués dans iOS.
> Si on ajoute un modèle CoreML plus tard, il devra être < 5 MB, quantisé INT8.

---

## 3. Architecture — MVVM simplifié

```
┌─────────────────────────────────────────────┐
│                   VIEWS                      │
│  (SwiftUI — tout ce que l'utilisateur voit)  │
├─────────────────────────────────────────────┤
│                VIEWMODELS                    │
│  (État, logique métier, orchestration)       │
├─────────────────────────────────────────────┤
│                 SERVICES                     │
│  (AR, Haptics, Audio, Vision — moteurs)      │
├─────────────────────────────────────────────┤
│              MODELS / UTILS                  │
│  (Structures de données, helpers)            │
└─────────────────────────────────────────────┘
```

**Règle fondamentale** : les Views n'appellent jamais un Service directement.
Tout passe par un ViewModel.

---

## 4. Arborescence des fichiers

```
SonicVision.swiftpm/
│
├── Package.swift
├── TECHNICAL_DOSSIER.md          ← ce fichier
│
├── App/
│   ├── SonicVisionApp.swift       ← @main, point d'entrée
│   └── AppState.swift             ← état global (mode, session active, etc.)
│
├── Models/
│   ├── SonarReading.swift         ← struct : distance, direction, confiance
│   ├── DetectedObject.swift       ← struct : label, confiance, timestamp
│   ├── FeedbackIntensity.swift    ← struct/enum : mapping distance → intensité
│   └── AppSettings.swift          ← struct : tous les réglages utilisateur
│
├── Services/
│   ├── ARDepthService.swift       ← gère ARSession, extrait sceneDepth
│   ├── HapticService.swift        ← gère CHHapticEngine, patterns continus
│   ├── AudioService.swift         ← audio spatial directionnel
│   ├── SpeechService.swift        ← AVSpeechSynthesizer pour annonces
│   └── VisionService.swift        ← détection objets offline (Vision framework)
│
├── ViewModels/
│   ├── SessionViewModel.swift     ← orchestre la session (start/stop/pause)
│   ├── SonarViewModel.swift       ← transforme depth → données sonar pour UI
│   ├── SettingsViewModel.swift    ← gère les réglages
│   └── OnboardingViewModel.swift  ← état de l'onboarding
│
├── Views/
│   ├── ContentView.swift          ← routeur principal (onboarding vs session)
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingPageView.swift
│   ├── Session/
│   │   ├── SessionView.swift      ← écran principal pendant le scan
│   │   ├── SonarOverlayView.swift ← visualisation sonar (cercles animés)
│   │   ├── HUDView.swift          ← distance, mode, dernier objet
│   │   └── ARViewContainer.swift  ← UIViewRepresentable pour ARSCNView/ARView
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       ├── GlassCard.swift        ← composant réutilisable style Glass
│       ├── PulseCircle.swift      ← animation cercle sonar
│       └── ModePickerView.swift   ← sélecteur Scan/Guidance/Identify
│
└── Utils/
    ├── DepthProcessor.swift       ← lissage, moyenne, anti-jitter
    ├── DistanceMapper.swift       ← distance → intensité (courbe configurable)
    ├── RateLimiter.swift          ← throttle générique (pour Vision, Speech)
    ├── SmoothedValue.swift        ← filtre passe-bas pour valeurs continues
    └── Constants.swift            ← constantes globales, seuils par défaut
```

---

## 5. Description de chaque module

### 5.1 — ARDepthService

**Rôle** : Lancer une ARSession avec `.sceneDepth`, extraire la depth map à chaque frame.

**Entrée** : rien (auto-démarre)
**Sortie** : publie un `SonarReading` (distance minimale devant, direction, confiance)

**Points critiques** :
- Vérifier `ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)` au lancement
- Si LiDAR absent → publier un état `.unavailable` (fallback UI)
- Extraire la distance depuis le **centre** de la depth map (zone ~20% centrale)
- Aussi calculer la distance à **gauche** et **droite** (zones latérales) pour la direction
- Fréquence : chaque ARFrame (30-60 FPS), mais le traitement lourd est throttlé

**API clé** :
```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let depthMap = frame.sceneDepth?.depthMap else { return }
    // Extraire distances centre/gauche/droite
    // Publier SonarReading
}
```

### 5.2 — HapticService

**Rôle** : Traduire une distance en vibration continue via Core Haptics.

**Entrée** : `FeedbackIntensity` (intensité 0→1, sharpness 0→1)
**Sortie** : vibration physique sur l'iPad

**Points critiques** :
- Créer le `CHHapticEngine` une seule fois, le garder actif
- Utiliser des **continuous events** (pas des transitoires répétés)
- Mettre à jour les paramètres dynamiquement via `CHHapticDynamicParameter`
- Gérer le `engine.stoppedHandler` et `engine.resetHandler` pour la robustesse
- Ne PAS recréer de pattern à chaque frame — mettre à jour les paramètres seulement

**Mapping distance → haptique** :
```
Distance 3.0m → intensité 0.05, sharpness 0.1  (presque rien)
Distance 1.5m → intensité 0.3, sharpness 0.3   (léger)
Distance 0.5m → intensité 0.7, sharpness 0.7   (fort)
Distance 0.2m → intensité 1.0, sharpness 1.0   (maximum, danger)
```
Courbe : **exponentielle inverse** (pas linéaire — la perception humaine n'est pas linéaire)

### 5.3 — AudioService

**Rôle** : Produire un son directionnel qui indique où est l'obstacle le plus proche.

**Entrée** : direction (gauche/centre/droite) + distance
**Sortie** : son spatialisé

**Points critiques** :
- Utiliser `AVAudioEngine` + `AVAudioPlayerNode` + `AVAudioEnvironmentNode`
- Pan stéréo : -1 (gauche), 0 (centre), +1 (droite)
- Fréquence du bip : plus rapide quand plus proche (comme un radar de recul)
- Son simple : tone synthétique (pas de fichier audio = économie de taille)
- Mode "off" doit couper proprement sans artefact

### 5.4 — SpeechService

**Rôle** : Annoncer vocalement les objets détectés ("Person ahead", "Chair").

**Entrée** : label (String) + optionnel direction
**Sortie** : synthèse vocale

**Points critiques** :
- `AVSpeechSynthesizer` — 100% offline
- Voix compacte en anglais (`com.apple.voice.compact.en-US`)
- **Cooldown par label** : ne pas répéter le même objet avant X secondes (défaut : 5s)
- File d'attente : si plusieurs objets détectés, prioriser le plus proche
- Ne pas interrompre une annonce en cours

### 5.5 — VisionService

**Rôle** : Détecter des objets dans le flux caméra AR, offline.

**Entrée** : `CVPixelBuffer` (image de la caméra AR)
**Sortie** : liste de `DetectedObject`

**Points critiques** :
- Utiliser `VNRecognizeAnimalsRequest` (personnes + animaux) — gratuit, offline, intégré
- Optionnel : `VNClassifyImageRequest` pour classifier la scène
- **Throttle à 2 FPS max** — Vision est coûteux, on ne traite pas chaque frame
- Seuil de confiance minimum : 0.6 (éviter les faux positifs)
- Stabilisation : ne publier un label que s'il apparaît X frames consécutives

---

## 6. Modèles de données

### SonarReading
```swift
struct SonarReading {
    let centerDistance: Float    // mètres, devant l'utilisateur
    let leftDistance: Float      // mètres, zone gauche
    let rightDistance: Float     // mètres, zone droite
    let confidence: Float        // 0-1, confiance depth
    let timestamp: TimeInterval
}
```

### DetectedObject
```swift
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String            // "Person", "Cat", "Chair"
    let confidence: Float
    let timestamp: Date
}
```

### AppSettings
```swift
struct AppSettings {
    var hapticSensitivity: Float = 1.0      // multiplicateur 0.5–2.0
    var minDistance: Float = 0.3             // mètres
    var maxDistance: Float = 3.0             // mètres
    var audioEnabled: Bool = true
    var audioVolume: Float = 0.7
    var speechEnabled: Bool = true
    var speechCooldown: TimeInterval = 5.0  // secondes entre annonces
    var visionEnabled: Bool = true
    var visionConfidenceThreshold: Float = 0.6
}
```

### FeedbackIntensity
```swift
struct FeedbackIntensity {
    let hapticIntensity: Float   // 0–1
    let hapticSharpness: Float   // 0–1
    let audioFrequency: Float    // Hz du bip
    let audioPan: Float          // -1 gauche, 0 centre, +1 droite
}
```

---

## 7. Flux de données principal

```
ARSession (30-60 FPS)
    │
    ├──► ARDepthService
    │       │
    │       ▼
    │    DepthProcessor (lissage, anti-jitter)
    │       │
    │       ▼
    │    SonarReading (centre, gauche, droite)
    │       │
    │       ├──► DistanceMapper → FeedbackIntensity
    │       │       │
    │       │       ├──► HapticService (vibration continue)
    │       │       └──► AudioService (bip directionnel)
    │       │
    │       └──► SonarViewModel → SonarOverlayView (UI)
    │
    └──► VisionService (throttle 2 FPS)
            │
            ▼
         DetectedObject
            │
            ├──► SpeechService (annonce vocale)
            └──► HUDView (affiche dernier objet)
```

---

## 8. Ordre de construction (build plan)

Construire dans cet ordre. Chaque phase doit compiler et fonctionner
avant de passer à la suivante.

### Phase 1 — Squelette (Jour 1)
1. `Package.swift` + structure des dossiers
2. `SonicVisionApp.swift` + `ContentView.swift` (juste un texte "Hello")
3. `AppSettings.swift` + `Constants.swift`
4. **Test** : l'app compile et affiche "Hello" sur iPad

### Phase 2 — AR + Depth (Jour 2)
1. `ARViewContainer.swift` (UIViewRepresentable minimal)
2. `ARDepthService.swift` (extraction depth map)
3. `SonarReading.swift`
4. `DepthProcessor.swift` + `SmoothedValue.swift`
5. `SessionViewModel.swift` (start/stop)
6. `SessionView.swift` (affiche la distance en texte)
7. **Test** : l'app affiche la distance réelle devant l'iPad

### Phase 3 — Haptique (Jour 3)
1. `FeedbackIntensity.swift`
2. `DistanceMapper.swift`
3. `HapticService.swift`
4. Connecter : distance → mapper → haptique dans SessionViewModel
5. **Test** : approcher un mur = vibration qui augmente

### Phase 4 — Audio directionnel (Jour 4)
1. `AudioService.swift`
2. Connecter : direction + distance → audio dans SessionViewModel
3. **Test** : obstacle à gauche = son à gauche

### Phase 5 — UI Sonar + HUD (Jour 5-6)
1. `GlassCard.swift` + `PulseCircle.swift`
2. `SonarOverlayView.swift` (cercles concentriques animés)
3. `HUDView.swift` (distance, mode, confiance)
4. `ModePickerView.swift`
5. Intégrer dans `SessionView.swift`
6. **Test** : l'UI est belle, fluide, lisible

### Phase 6 — Vision + Speech (Jour 7-8)
1. `VisionService.swift`
2. `DetectedObject.swift`
3. `RateLimiter.swift`
4. `SpeechService.swift`
5. Connecter dans SessionViewModel
6. **Test** : pointer vers une personne → annonce "Person"

### Phase 7 — Onboarding + Settings (Jour 9)
1. `OnboardingView.swift` + `OnboardingPageView.swift`
2. `OnboardingViewModel.swift`
3. `SettingsView.swift` + `SettingsViewModel.swift`
4. Routage dans `ContentView.swift`
5. **Test** : premier lancement = onboarding, puis session

### Phase 8 — Polish & Edge Cases (Jour 10+)
1. Gestion d'erreurs (pas de LiDAR, permissions refusées)
2. Animations et transitions
3. VoiceOver / Dynamic Type
4. Optimisation mémoire et batterie
5. Test intensif sur iPad
6. **Test final** : démo 45 secondes fluide de bout en bout

---

## 9. Gestion des erreurs et fallbacks

| Situation | Comportement |
|---|---|
| Pas de LiDAR | Message clair "LiDAR required" + mode démo simulé |
| Caméra refusée | Demande permission + écran explicatif |
| Haptic engine crash | Redémarrage auto du CHHapticEngine |
| Vision trop lent | Réduction auto du throttle (1 FPS) |
| Depth map nil | Ignorer la frame, garder la dernière valeur valide |
| Mémoire haute | Réduire buffer Vision, désactiver si critique |

---

## 10. Règles de code

1. **Un fichier = une responsabilité.** Pas de fichier > 200 lignes.
2. **Pas de force unwrap** (`!`) sauf sur des constantes garanties.
3. **Pas de print()** en production — utiliser un Logger conditionnel.
4. **@Published** pour tout état observable dans les ViewModels.
5. **@MainActor** sur les ViewModels (mise à jour UI thread-safe).
6. **Nommage clair** : `updateHapticFeedback(for distance:)` pas `update()`.
7. **Commentaires MARK** pour la navigation : `// MARK: - Depth Processing`.
8. **Pas de dépendance externe** (SPM packages) — uniquement frameworks Apple.
9. **Tester sur iPad à chaque phase**, pas à la fin.

---

## 11. Seuils et constantes par défaut

```swift
enum Defaults {
    // Distance
    static let minDistance: Float = 0.2          // mètres (danger immédiat)
    static let maxDistance: Float = 3.0          // mètres (limite de détection utile)
    static let depthSmoothingFactor: Float = 0.3 // filtre passe-bas (0=lent, 1=brut)

    // Haptique
    static let hapticUpdateInterval: TimeInterval = 0.05  // 20 Hz
    static let hapticMinIntensity: Float = 0.05
    static let hapticMaxIntensity: Float = 1.0

    // Audio
    static let audioMinFrequency: Float = 200    // Hz (loin)
    static let audioMaxFrequency: Float = 1200   // Hz (proche)
    static let audioMinInterval: TimeInterval = 0.8  // secondes entre bips (loin)
    static let audioMinIntervalClose: TimeInterval = 0.1  // secondes (proche)

    // Vision
    static let visionThrottleFPS: Double = 2.0
    static let visionMinConfidence: Float = 0.6
    static let speechCooldown: TimeInterval = 5.0

    // UI
    static let sonarRingCount: Int = 5
    static let sonarAnimationDuration: Double = 1.5
}
```

---

## 12. Checklist "Distinguished Winner"

- [ ] L'app fonctionne parfaitement offline
- [ ] L'app fait < 25 MB
- [ ] Le LiDAR → haptique est fluide et intuitif
- [ ] L'audio directionnel fonctionne
- [ ] L'UI Liquid Glass est soignée et professionnelle
- [ ] L'onboarding est clair (< 30 secondes)
- [ ] Les réglages sont fonctionnels
- [ ] VoiceOver est supporté
- [ ] Dynamic Type est supporté
- [ ] La démo 45s est fluide sans crash
- [ ] Le fallback "pas de LiDAR" est géré
- [ ] Le pitch 30s est mémorisé
- [ ] L'essay de soumission est rédigé
- [ ] Le code est propre, commenté, bien structuré

---

*Dernière mise à jour : Février 2026*
*Ce document doit rester synchronisé avec l'état réel du projet.*
