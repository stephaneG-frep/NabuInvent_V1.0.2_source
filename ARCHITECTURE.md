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
├── main.dart               # amorçage, providers, thèmes, porte d'entrée onboarding
├── ai/
│   ├── ai_response.dart    # contrat de réponse + prompt système partagé
│   ├── ai_provider.dart    # abstraction AiProvider + service de dispatch
│   ├── offline_engine.dart # moteur local (hors ligne) — logique embarquée
│   └── openai_provider.dart# client OpenAI-compatible (HTTP)
├── models/                 # inventions, plans, chats, journal, étincelles, backlog…
├── services/
│   ├── settings_service.dart  # préférences (mode IA, clé API, thème, quota…)
│   └── storage_service.dart   # persistance JSON + export/import/remise à zéro
├── state/
│   ├── app_state.dart      # état global, acheminement IA, « applyResponse »
│   └── tab_bus.dart        # navigation inter-onglets
├── theme/app_theme.dart    # Material 3, 10 couleurs d'accent, clair/sombre
├── screens/                # 10 écrans (Accueil, Projets, Studio, Étincelles…)
└── widgets/                # cartes de projet, cartes de réponse, briques communes
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

## Tests

30 tests unitaires :

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

Version gérée dans `pubspec.yaml` (`1.0.2+3`). APK universel + APK par ABI
(arm64, arm32, x86_64). Signés debug pour installation manuelle.
Identifiant d'application : `com.nabu.invent`.