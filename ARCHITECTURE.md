# Architecture technique — NabuInvent AI

## Vue d'ensemble

Application Flutter **Android uniquement**, organisée en couches classiques :
**UI (screens) → État (state) → Services (persistance/configuration) → IA (moteurs)**.
Le modèle de données est sérialisé en JSON. `AppData` est immuable (`copyWith`) ;
les projets et étapes sont modifiés en place puis remplacés dans `AppData`.
La lecture JSON est tolérante (`models/json_utils.dart`) : un nombre renvoyé en
chaîne par un modèle cloud ne fait pas échouer la réponse.

```
lib/
├── main.dart                 # amorçage, providers, thèmes, porte d'entrée onboarding
├── ai/
│   ├── ai_response.dart      # contrat de réponse (concepts, techSheet…) + prompt système
│   ├── ai_provider.dart      # AiProvider, VisionProvider, AiService, erreurs lisibles
│   ├── openai_provider.dart  # client OpenAI-compatible : texte, image (vision), annulation
│   ├── image_generator.dart  # client /images/generations + styles + prompt d'aperçu
│   ├── offline_engine.dart   # moteur local (hors ligne)
│   ├── offline_atelier.dart  # concepts et idées par ressources, en local
│   ├── lenient_json.dart     # décodage tolérant / réparation des JSON tronqués
│   ├── display_reply.dart    # ce qu'une bulle affiche (y compris anciennes réponses brutes)
│   └── redact.dart           # masquage des clés dans les textes bruts
├── models/                   # projets (+ versions, aperçus, contraintes), plans, concepts,
│                             # fiche technique, analyse de photo, chats, journal…
├── tech/
│   ├── material_calculator.dart  # calculs déterministes (découpe, surfaces, budget)
│   ├── safety_checker.dart       # contrôles de sécurité déterministes
│   └── tech_sheet_builder.dart   # fiche de départ sans IA (cotes inconnues)
├── export/
│   ├── project_exporter.dart # PDF, PNG (rendu hors écran), JSON, ZIP
│   └── project_text.dart     # version texte d'un projet
├── services/                 # réglages (clés chiffrées), stockage (images, exports)
├── state/                    # AppState (IA, versions, mémoire, annulation), TabBus
├── theme/                    # Material 3, 12 accents dont Cuivre et Bronze
├── screens/                  # Accueil, Projets, Studio, Atelier, Réglages + photo,
│                             # galerie de concepts, conception technique, fabrication,
│                             # studio visuel, versions, export…
└── widgets/                  # fiches d'invention, concepts, rendu de texte, dessins techniques
```

## Flux principal — une demande IA

```
Écran (Studio) ──askAi(...)──▶ AppState
                                  │
                                  ▼
                          AiProvider.resolve(...)
                        /                    \
             offline_engine            openai_provider
                  │                        │
                  ▼                        ▼
            NabuAiResponse          NabuAiResponse (JSON parsé)
                  │                        │
                  ▼                        ▼
              AppState._applyResponse
             ├── ajoute le tour de chat
             ├── transforme la réponse en projet/plan/éval/journal
             ├── persiste (notifyListeners)
             ▼
             UI se met à jour (Provider)
```

## Le contrat de réponse (`NabuAiResponse`)

Tous les moteurs répondent sous la même forme :

| Champ | Rôle |
|---|---|
| `message` | Réponse lisible courante en français |
| `intent` | `invent`, `plan`, `evaluate`, `spark`, `journal`, `name`, `none` |
| `messageType` | `success` / `info` / `warning` / `error` |
| `project` | Fiche invention (créée ou mise à jour) |
| `plan` | Plan de construction avec étapes |
| `evaluation` | Évaluation chiffrée (score /10) |
| `spark` | Étincelle de créativité |
| `journalText` | Note de journal à ajouter |
| `nudge` | Texte affiché sous un titre d'accueil |

Le moteur local produit cette structure directement ; le provider cloud demande au
modèle de renvoyer un **JSON strict** (`respondJson`) et le parse avec repli en
texte seul si le modèle ne renvoie pas de JSON valide.

## Le moteur hors ligne (`offline_engine.dart`)

- Analyse des demandes par mots-clés français (≥ N correspondances) pour
  déterminer l'intention.
- **Générateur d'inventions** : databank de 12 domaines × 10+ inventions
  (mécanique, électronique, jardin, cuisine, bureau, espace, animaux, santé,
  voyage, sport, domotique, école) fusionnées par la forme « élément + contexte ».
- Plans, évaluations (scores et commentaires générés), étincelles à partir de
  couples de thèmes aléatoires, et notes de journal.
- Aucune sortie réseau : le quota d'étincelles (12/jour) est géré côté état.

## État et persistance

- `AppData` : inventaires des projets, journaux, chats, étincelles (vault), backlog,
  projets actifs (`.activeProjectId`, `.performantProjectId`).
- `SettingsService` (SharedPreferences ; clé API dans `flutter_secure_storage`,
  migrée automatiquement depuis les versions ≤ 1.0.2) : mode d'IA, URL de base, modèle,
  thème/accent, onboarding, date de quota.
- `StorageService` (dossier documents) : écritures sérialisées dans une file,
  écriture atomique (`.tmp` puis `rename`) avec copie `.bak` ; un fichier
  illisible est mis de côté (`.corrompu_<date>`) et la copie `.bak` est relue.
  Export horodaté, import (remplacement), remise à zéro.

## Principes de l'atelier d'invention

- **Jamais de JSON brut** : `LenientJson` répare, `DisplayReply` ré-interprète à l'affichage.
- **L'IA propose, l'application calcule** : cotes de l'IA = hypothèses étiquetées ;
  quantités, découpes, budget et état du plan viennent de `tech/`.
- **Rien n'est simulé** : sans fournisseur multimodal ou d'images, la fonction est indiquée
  comme indisponible.
- **Rien n'est écrasé** : instantané (`ProjectVersion`) avant chaque modification par l'IA ;
  une proposition ne remplace jamais une mesure de l'utilisateur.

## Tests

84 tests (voir `RAPPORT_TESTS.md`) :

- `test/core_test.dart` — moteur local (invention, plan, évaluation, étincelle,
  journal), parsing des réponses cloud (JSON valide + repli texte seul),
  encodage/décodage `AppData`.
- `test/regression_test.dart` — détection d'intention (mots entiers),
  parsing tolérant, ids d'étapes uniques, `AppState._applyResponse`
  (aucun projet écrasé, plan cloud rattaché), historique envoyé à l'IA.
- `test/storage_test.dart` — persistance réelle sur disque : écritures
  concurrentes, fichier corrompu, copie `.bak`, remise à zéro.

Commandes de vérification :

```bash
flutter analyze   # « No issues found! »
flutter test      # « All tests passed! »
```

## Construction

Version gérée dans `pubspec.yaml` (`1.0.3+4`). APK universel + APK par ABI
(arm64, arm32, x86_64). Signés avec la clé release (`android/key.properties`,
voir README) ; R8 est désactivé (`shared_preferences_android` passe par JNI).
Identifiant d'application : `com.nabu.invent`.