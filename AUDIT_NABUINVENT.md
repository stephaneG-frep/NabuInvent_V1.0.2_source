# Audit NabuInvent AI — base de départ de l'« Atelier d'invention »

Date : 3 novembre 2026 · Version auditée : 1.0.3+4 (branche `release-1.0.3`)

## 1. Plateformes et dépendances

| Élément | Constat |
|---|---|
| Plateformes configurées | **Android uniquement** (`android/`). Pas de `linux/`, `ios/`, `web/` : aucun paquet `.deb` possible sans ajouter la cible Linux. |
| Flutter / Dart | Dart `^3.12.2`, Material 3 |
| État | `provider` (`AppState` ChangeNotifier global + `TabBus` pour les onglets) |
| Persistance | `nabuinvent_data.json` (écriture atomique + `.bak`), réglages dans SharedPreferences, clé API dans `flutter_secure_storage` |
| Réseau | `http`, fournisseur unique compatible OpenAI (`/chat/completions`) |
| Fichiers | `file_picker` (import JSON), `share_plus` (partage de l'export) |
| Signature | clé release (`android/key.properties`, hors dépôt) ; R8 désactivé (shared_preferences_android passe par JNI) |
| Tests | 34 tests unitaires (moteur local, parsing, AppState, stockage, fournisseur HTTP simulé) |

## 2. Architecture

```
UI (screens/, widgets/) ──▶ AppState (state/) ──▶ AiService ──▶ OfflineEngine | OpenAICompatibleProvider
                              │                                      └─ NabuAiResponse (contrat JSON)
                              └─▶ StorageService / SettingsService
```

- **Écrans** : Accueil, Projets, Studio, Étincelles, Réglages (barre du bas) ; fiche projet,
  plan, journal, réserve d'idées, guide, onboarding (navigation `push`).
- **Modèles** : `InventionProject` (+ `ProjectPlan` / `PlanStep`), `IdeaEvaluation`, `Spark`,
  `ChatTurn`, `JournalEntry`, `BacklogIdea`, regroupés dans `AppData`.
- **IA** : contrat `NabuAiResponse` (message, intent, project, plan, evaluation, spark,
  journalText). Le moteur local répond par mots-clés et gabarits ; le cloud reçoit un prompt
  système demandant un JSON strict.

L'architecture en couches est saine : elle est conservée et étendue.

## 3. Studio d'invention

- `StudioScreen` : `Column` → `Expanded(ListView.builder)` + puce de projet actif + raccourcis
  + barre de saisie. Une seule liste verticale, pas de défilement imbriqué.
- Chaque tour assistant est une bulle (`_MessageBubble`) : texte `turn.content` puis cartes
  selon le `payload` stocké (projet, évaluation, étincelle).

### Bug 1 — JSON brut dans les bulles (confirmé par lecture du code)

1. `OpenAICompatibleProvider` limite la réponse à `max_tokens: 1800`. Une invention complète
   avec plan dépasse souvent cette taille : le JSON du modèle est **coupé**.
2. `NabuAiResponse.parse` ne sait pas réparer un JSON tronqué : en cas d'échec il renvoie
   **tout le texte brut** comme `message`.
3. La bulle affiche `turn.content` tel quel, dans un `Text` : l'utilisateur voit le JSON
   (`materials`, `tools`, `budget`, `timeEstimate`…).
4. Les réponses déjà enregistrées ainsi restent brutes dans l'historique : il faut aussi
   les **ré-interpréter à l'affichage**.

Autres causes possibles couvertes par le correctif : blocs ```` ```json ```` entourés de texte,
JSON avec virgules finales, message vide.

### Bug 2 — défilement bloqué (confirmé par lecture du code)

`studio_screen.dart` enveloppe la liste dans un `NotificationListener<ScrollNotification>` :

```dart
if (notif.metrics.pixels >= notif.metrics.maxScrollExtent - 8) {
  _scrollBottom();   // animateTo(maxScrollExtent)
}
```

Dès que la liste est à moins de 8 px du bas, **chaque** notification (y compris celles du
geste de l'utilisateur qui remonte) relance une animation vers le bas. Avec une grande bulle
en fin de conversation, l'utilisateur est toujours « près du bas » au début de son geste :
l'animation reprend la main et il ne peut plus remonter. Aucun défilement imbriqué n'est en
cause.

Corrections prévues : supprimer cet écouteur, ne défiler automatiquement qu'à l'arrivée d'un
nouveau message **si** l'utilisateur était déjà en bas, ajouter un bouton « Dernier message ».

## 4. Fonctionnalités existantes

| Domaine | Existant | Limites |
|---|---|---|
| Invention | 1 projet par demande (local : banque de 12 domaines ; cloud : modèle) | Pas de variantes, pas de compréhension « deux objets » |
| Évaluation | Scores originalité/faisabilité/impact | — |
| Étincelles | Combinaisons aléatoires, quota local 12/jour | — |
| Plan | Étapes cochables, progression | Pas de cotes, pas de vues, pas de nomenclature |
| Calculs | **Aucun** : budget/durée sont des textes libres | Rien de vérifiable |
| Images | **Aucun** service de génération ni d'analyse d'image | — |
| Sécurité | Champ `safety` texte par étape | Aucun contrôle déterministe |
| Historique | Chat global (10 derniers tours envoyés) ; fusion des projets sans perte de champs | **Pas de versions** de projet : une modification remplace l'état précédent |
| Export | JSON complet (partage) ; import = remplacement | Pas de PDF, PNG, ZIP ; pas de choix de destination |
| Hors ligne | Moteur local complet | — |

## 5. Points d'attention pour la suite

- Toute nouvelle donnée doit rester lisible par les anciennes versions du fichier JSON
  (champs optionnels, valeurs par défaut) : les utilisateurs ont des données réelles.
- Le moteur local doit rester honnête : il ne peut ni analyser une photo ni générer d'image.
  Ces fonctions seront **désactivées et signalées** hors cloud, jamais simulées.
- Les dimensions, quantités et budgets doivent venir de **fonctions Dart testées**, le modèle
  IA ne fournissant que des hypothèses étiquetées comme telles.
- Photos : consentement explicite avant tout envoi à un fournisseur externe.
- Génération d'images : fournisseur séparé (`/images/generations`) avec sa propre clé ;
  le fournisseur de texte actuel (ex. Anthropic) n'en génère pas.
