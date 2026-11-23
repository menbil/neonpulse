# 🎮 NeonPulse - Jeu de Rythme EBA

## 🚀 Améliorations Appliquées

### ✅ Système de Score Avancé
- **Système de combo** avec multiplicateur (jusqu'à x4.0)
- **Tracking détaillé** : Perfect, Good, Miss séparément
- **Calcul d'accuracy** et statistiques complètes
- **Nouveau système de rang** basé sur la performance

### ✅ Nouveaux Types de Notes
- **Notes Standard** : Tap classique
- **Notes Hold** : Maintenir appuyé
- **Double Tap** : Cliquer deux fois rapidement
- **Swipe Notes** : Notes avec direction (base implémentée)

### ✅ Effets Visuels Améliorés
- **Shader avancé** avec analyse spectrale multi-bandes
- **Effets de combo** visuels
- **Screen shake** lors de gros combos
- **Paramètres visuels** configurables (luminosité, contraste)

### ✅ Système Audio Professionnel
- **Analyseur spectral** 7 bandes (sub-bass à brilliance)
- **Détection de beats** automatique
- **Effets audio réactifs** sur le shader
- **Support de l'analyse fréquentielle**

### ✅ Système de Paramètres
- **GameSettings complet** avec persistance
- **Paramètres de gameplay** (vitesse, taille des notes, offset audio)
- **Options d'accessibilité** (daltonisme, haut contraste)
- **Paramètres audio** (volumes maître, musique, SFX)

### ✅ Système de Progression
- **Niveaux de joueur** avec expérience
- **Achievements** déblocables
- **Statistiques détaillées** par session
- **Historique des performances**

### ✅ Mode d'Entraînement
- **Vitesse variable** (0.25x à 2.0x)
- **Section practice** avec loop
- **Aide visuelle** configurable
- **Métronome intégré**
- **Recommandations personnalisées**

### ✅ Interface Améliorée
- **Sélecteur de difficulté** (Easy, Normal, Hard, Expert)
- **Prévisualisation audio** des tracks
- **Affichage des meilleurs scores**
- **Interface de debug** (F1-F4)

### ✅ Générateur de Beatmap Avancé
- **4 niveaux de difficulté** avec paramètres adaptés
- **Support des nouveaux types de notes**
- **Génération par ligne de commande** améliorée
- **Algorithmes de placement** optimisés

### ✅ Optimisations Performance
- **Pooling amélioré** pour notes et particules
- **Extension dynamique** des pools
- **Gestion mémoire** optimisée
- **Debug profiling** intégré

## 🎯 Utilisation

### Configuration Initiale
1. **Exécuter le script de setup** : `scripts/setup_neonpulse.gd` dans l'éditeur
2. **Redémarrer le projet** pour appliquer les autoloads
3. **Configurer les paramètres** dans le menu (bouton Settings)

### Générateur de Beatmap
```bash
# Utilisation basique
python generate_beatmap.py music.ogg

# Avec difficulté spécifique
python generate_beatmap.py music.ogg output.json 1152 648 zones normal

# Difficulté expert
python generate_beatmap.py music.ogg expert_beatmap.json 1152 648 zones expert
```

### Contrôles Debug
- **F1** : Toggle mode debug
- **F2** : Afficher les fenêtres de timing
- **F3** : Informations des notes
- **F4** : Mode d'entraînement
- **Échap** : Pause

### Nouveaux Paramètres
Accessible via le menu Settings :
- **Approach Speed** : Vitesse d'approche des notes
- **Note Size** : Taille des notes
- **Audio Offset** : Correction du décalage audio
- **Visual Effects** : Activer/désactiver les effets
- **Auto Play** : Mode automatique pour les tests

## 📁 Structure des Fichiers

```
scripts/
├── GameSettings.gd          # Gestion des paramètres
├── ProgressionSystem.gd     # Système XP et achievements
├── AudioAnalyzer.gd         # Analyse audio avancée
├── DebugManager.gd          # Outils de debug
├── TrainingMode.gd          # Mode d'entraînement
├── GlobalManager.gd         # Gestionnaire principal
├── Main.gd                  # Jeu principal (amélioré)
├── Note.gd                  # Notes avec nouveaux types
├── HighscoreManager.gd      # Scores avec historique
└── TrackSelector.gd         # Sélection avec preview
```

## 🎵 Format des Beatmaps

Les beatmaps supportent maintenant :
```json
{
  "notes": [
    {
      "event_type": "single_note",
      "note": {
        "time": 2.59,
        "type": "kick",
        "note_type": "double_tap",
        "x": 594,
        "y": 541
      }
    },
    {
      "event_type": "combo",
      "combo_type": "jackhammer",
      "notes": [...]
    }
  ]
}
```

### Types de Notes Supportés
- `"tap"` : Note standard
- `"hold"` : Note à maintenir (avec `duration`)
- `"double_tap"` : Double clic rapide
- `"swipe"` : Note avec direction (avec `swipe_x`, `swipe_y`)

## 🔧 Configuration Technique

### Autoloads Requis
- `GlobalManager` : Gestionnaire principal
- `GameSettings` : Paramètres de jeu
- `ProgressionSystem` : Progression du joueur
- `AudioAnalyzer` : Analyse audio
- `DebugManager` : Outils de debug

### Dépendances Python (pour le générateur)
```bash
pip install librosa madmom numpy
```

## 📈 Futures Améliorations Suggérées

### Court Terme
- [ ] Éditeur de beatmap visuel
- [ ] Mode multijoueur local
- [ ] Plus de types de notes (spin, flick)
- [ ] Thèmes visuels

### Moyen Terme
- [ ] Partage en ligne des scores
- [ ] Workshop communautaire
- [ ] Support VR
- [ ] Mode spectateur

### Long Terme
- [ ] Streaming des beatmaps
- [ ] Tournois en ligne
- [ ] Système de mods
- [ ] Support mobile

## 🐛 Debug et Dépannage

### Problèmes Courants
1. **Pas d'audio** : Vérifier les bus audio dans les paramètres du projet
2. **Notes ne s'affichent pas** : Vérifier le pooling et les shaders
3. **Lag visuel** : Réduire les effets dans GameSettings
4. **Beatmap vide** : Vérifier le format JSON et les chemins

### Outils de Debug
- Mode debug (F1) pour voir les métriques
- Console Godot pour les logs détaillés
- Profiler intégré pour les performances

---

**Créé avec ❤️ pour la communauté des jeux de rythme**
