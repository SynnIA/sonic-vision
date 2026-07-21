<div align="center">

# 🔊 Sonic Vision

### *Sentir l'espace. Entendre le monde.*

**Conscience spatiale multi-sensorielle pour personnes aveugles et malvoyantes —
la profondeur LiDAR convertie en toucher et en son, entièrement sur l'appareil.**

[🇬🇧 English](README.md) · **Français**

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/iPadOS-17.0%2B-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid_Glass-0A84FF)
![Offline](https://img.shields.io/badge/R%C3%A9seau-100%25_hors_ligne-34C759)
![Dependencies](https://img.shields.io/badge/D%C3%A9pendances-0-8E8E93)
![Size](https://img.shields.io/badge/Source-~100_Ko-FF9F0A)
![License](https://img.shields.io/badge/Licence-MIT-blue)

*Ma candidature au **Swift Student Challenge 2026** d'Apple* 🍎

</div>

---

## 💡 L'idée

Fermez les yeux et essayez de traverser une pièce. Chaque pas est une question.

Un iPad Pro embarque un **scanner LiDAR** qui mesure la distance exacte de tout ce qui se trouve devant lui, soixante fois par seconde. Ces données alimentent d'habitude des jeux AR et des apps de scan — et si elles pouvaient nourrir **vos autres sens** ?

**Sonic Vision** convertit la profondeur en temps réel en deux canaux intuitifs :

- 🤲 **Haptique** — plus l'obstacle est proche, plus la vibration est forte et sèche, selon une courbe exponentielle inverse calquée sur la perception humaine (pas un bête mapping linéaire).
- 🎧 **Audio spatial 3D** — un ping façon sonar, positionné dans l'espace réel autour de votre tête grâce au rendu HRTF. Un obstacle à votre gauche *sonne* comme s'il était à votre gauche.
- 🗣️ **Reconnaissance sur l'appareil** — le framework Vision identifie personnes et objets dans la scène et les affiche en étiquettes AR flottantes, sans fichier de modèle ML et sans cloud.

Pointez l'iPad vers le monde, et le monde répond — par vos mains et vos oreilles. Tout est calculé sur l'appareil, avec **zéro appel réseau et zéro collecte de données**.

> ⚠️ Sonic Vision est un outil expérimental et complémentaire — **pas** un dispositif médical, et pas un remplacement de la canne blanche, du chien guide ou de la formation O&M.

---

## 📖 L'histoire du projet

Je voulais que ma candidature au Swift Student Challenge soit plus qu'une démo — qu'elle défende une idée : **des outils d'accessibilité sérieux peuvent être minuscules, privés et immédiats.**

Le challenge impose des contraintes brutales : une app Swift Playgrounds (`.swiftpm`), **moins de 25 Mo**, jugée en trois minutes environ, fonctionnant totalement **hors ligne**. La plupart y voient des limites. J'en ai fait le cahier des charges :

- **Aucun fichier de modèle CoreML.** Au lieu d'embarquer un réseau de plusieurs Mo, j'ai combiné les détecteurs intégrés du framework Vision (`VNDetectHumanRectanglesRequest`, `VNDetectRectanglesRequest`, `VNClassifyImageRequest`) avec des heuristiques géométriques. La détection coûte **0 octet** d'assets.
- **Aucun fichier audio.** Chaque ping sonar est une **onde sinusoïdale synthétisée par le code** — buffers PCM pré-calculés à 400 / 800 / 1200 Hz avec enveloppe anti-clic, puis spatialisés via `AVAudioEnvironmentNode` en rendu HRTF-HQ.
- **Aucune dépendance externe.** Frameworks Apple purs, rien d'autre.

Résultat : l'app entière tient dans **~100 Ko de source** — environ **0,4 %** du budget de taille.

Détail de production inhabituel dont je suis un peu fier : cette app iPad LiDAR a été conçue **sans Mac**. L'IDE cible est Swift Playgrounds sur iPad, et le code a été développé et audité depuis un environnement Windows/WSL2 — ce qui impose une discipline d'architecture d'abord, de lecture attentive des API et de revue systématique plutôt que d'essais-erreurs à la compilation.

Et cette discipline a été mise à l'épreuve. Avant soumission, j'ai mené un **audit complet** ([`AUDIT_REPORT.md`](AUDIT_REPORT.md) — conservé volontairement dans ce dépôt, bugs compris). Il a trouvé **9 problèmes**, dont trois vraiment humiliants :

1. 🕳️ La vue caméra AR faisait tourner en silence **sa propre `ARSession` séparée**, déconnectée du pipeline de profondeur — la démo aurait affiché un écran noir.
2. ⚡ Une **race condition** sur le pixel buffer caméra, écrit depuis le thread ARKit et lu depuis le thread principal.
3. 📉 Une **double multiplication** de l'intensité haptique qui rendait le curseur de sensibilité quadratique au lieu de linéaire.

Chaque problème critique a été corrigé, l'overlay sonar et les étiquettes AR construits, et le projet est passé de 1 441 à ~2 000 lignes — plus sobre en comportement, plus riche en expérience. Publier l'audit à côté du code est le message : l'ingénierie, ce n'est pas prétendre que les bugs n'ont jamais existé ; c'est les trouver avant vos utilisateurs (ou un jury).

---

## ⚙️ Comment ça marche

L'expérience entière est une table de traduction temps réel entre distance et sensation :

| Distance | Retour haptique | Ping audio |
|:---:|---|---|
| 3,0 m | bourdonnement à peine perceptible | lent, grave (~400 Hz) |
| 1,5 m | pulsation douce | rythme régulier (~800 Hz) |
| 0,5 m | fort, sec | rapide, aigu (~1200 Hz) |
| 0,2 m | urgence maximale | quasi continu — *danger* |

Chaque service tourne à sa propre cadence, aucun canal ne peut en affamer un autre :

| Service | Framework | Cadence | Rôle |
|---|---|:---:|---|
| `ARSessionManager` | ARKit | 10 Hz | capture profondeur LiDAR, échantillonnage ROI, mode simulation |
| `HapticEngine` | Core Haptics | 20 Hz max | patterns continus, redémarrage auto après reset |
| `SpatialAudioEngine` | AVFoundation | ~6,6 Hz | positionnement 3D HRTF, buffers sinus pré-calculés |
| `VisionDetector` | Vision | 2 Hz | détection personnes/objets sur l'appareil, seuil de confiance |

---

## ✨ Fonctionnalités

- 🔒 **100 % hors ligne, privacy-first** — aucun appel réseau, aucune analytics, aucune donnée ne quitte l'appareil
- 🤲 **Haptique progressive** — courbe d'intensité exponentielle inverse réglée sur la perception, avec échelle utilisateur
- 🎧 **Vrai audio 3D** — le rendu HRTF place les pings dans l'espace (AirPods recommandés)
- 👁️ **Détection sur l'appareil** — personnes et objets, zéro fichier de modèle ML
- 🌊 **Overlay sonar animé** — ondes concentriques, code couleur par proximité (cyan → orange → rouge)
- 🫧 **Design system Liquid Glass** — `.ultraThinMaterial` partout, échelle typographique SF Rounded, physique spring sur chaque interaction
- 🛟 **Dégradation gracieuse** — mode simulation sur iPad sans LiDAR, auto-récupération des moteurs, parcours permissions

---

## 🏛 Architecture

**MVVM + Services**, câblé avec Combine. Les vues ne touchent jamais un service directement — tout passe par le ViewModel.

<pre>
SonicVision.swiftpm/            ~2 000 lignes · 17 fichiers Swift · ~100 Ko
├── App        SonicVisionApp
├── Views      MainView · ARCameraView · ControlPanelView · SonarOverlayView
│              ARLabelNode · LiquidGlassCard · AccessibilityBadge
├── ViewModel  SonicViewModel (état central + coordination)
├── Services   ARSessionManager · HapticEngine · SpatialAudioEngine · VisionDetector
├── Models     DepthFrame · DetectedObject · HapticPattern
└── Design     DesignSystem (tokens Typo / Space / Radius / Anim)
</pre>

Choix d'ingénierie notables :

- **Pipeline événementiel** avec throttles indépendants par service (50 / 100 / 150 / 500 ms) — une frame lente dans un canal ne bloque jamais les autres.
- **Échantillonnage de profondeur par zones d'intérêt** (centre ~10 % + zones latérales) plutôt que scan du buffer complet.
- **Lissage passe-bas** pour tuer le jitter LiDAR avant qu'il n'atteigne vos doigts.
- **Aucun force unwrap, nettoyage déterministe** — chaque service possède son `deinit`, le moteur haptique s'auto-répare via `stoppedHandler` / `resetHandler`.

---

## 🚀 Lancer l'app

**Prérequis :** iPad Pro (2020+) avec LiDAR · iPadOS 17+ · casque recommandé (AirPods Pro idéal). Les iPad sans LiDAR ont un mode démo simulé.

1. Cloner le dépôt (ou récupérer `SonicVision.swiftpm`)
2. Ouvrir `SonicVision.swiftpm` dans **Swift Playgrounds 4+** sur iPad — ou dans **Xcode 15+** sur Mac
3. Build & run, autoriser la caméra, appuyer sur **Start**, pointer l'iPad vers la pièce
4. Avancer vers un mur. Le sentir avant de le toucher. 🤲

**Parcours démo 45 secondes** (le format du challenge) : scanner un bureau encombré → s'approcher d'un objet et sentir l'haptique monter → balayer la pièce et voir trois objets étiquetés pendant que l'audio les suit dans l'espace. Script complet dans [`Demo/Script_demo.md`](Demo/Script_demo.md).

---

## 📁 Contenu du dépôt

| Chemin | Ce que c'est |
|---|---|
| [`SonicVision.swiftpm/`](SonicVision.swiftpm) | L'app — package Swift Playgrounds complet |
| [`Document_tech/TECHNICAL_DOSSIER.md`](Document_tech/TECHNICAL_DOSSIER.md) | Le plan de construction écrit *avant* de coder : architecture, flux de données, plan en 8 phases, seuils |
| [`AUDIT_REPORT.md`](AUDIT_REPORT.md) | L'audit pré-soumission sans fard — 9 bugs trouvés, critiques corrigés |
| [`Demo/Script_demo.md`](Demo/Script_demo.md) | Le storyboard de la démo 45 secondes |

Ces documents de process sont publiés volontairement : le *comment* fait autant partie du portfolio que le *quoi*.

---

## ⚠️ Avertissements

**Sonic Vision n'est pas un dispositif médical.** C'est un outil expérimental et complémentaire de conscience spatiale, qui n'a été évalué par aucune autorité médicale ou réglementaire. Il ne remplace **pas** la canne blanche, le chien guide, la formation orientation & mobilité, ni aucune technologie d'assistance établie.

**Vie privée :** tout le traitement se fait sur l'appareil. Aucune image caméra, donnée de profondeur ou donnée d'usage n'est transmise, stockée ou partagée.

---

## 👤 À propos de moi

Je suis **Nathan** ([@SynnIA](https://github.com/SynnIA)), développeur français qui aime construire des produits complets sous fortes contraintes — convaincu que la meilleure preuve d'ingénierie est ce qu'on peut faire avec *moins* : moins de taille, moins de dépendances, moins de données collectées.

Sonic Vision est ma candidature au Swift Student Challenge 2026 : quatre frameworks Apple orchestrés en temps réel, dans ~100 Ko, sans rien cacher — pas même le rapport d'audit.

---

<div align="center">

**Licence MIT** · Construit avec Swift, ARKit, et la conviction que l'accessibilité mérite une belle ingénierie.

*Swift Student Challenge 2026*

<sub>

Créé avec soin par <b><a href="https://nathanfernandes.fr">Nathan Fernandes</a></b> — Fondateur de SYNN-IA · Dijon, France

🌐 <a href="https://nathanfernandes.fr">Portfolio</a> · 💼 <a href="https://www.linkedin.com/in/nathan-fernandes-a5793b377/">LinkedIn</a> · 🐙 <a href="https://github.com/SynnIA">GitHub</a>

</sub>
</div>
