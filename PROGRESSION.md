# Progression — Atelier d'invention NabuInvent AI

Branche de travail : `atelier-invention` (créée depuis `release-1.0.3`).

| Phase | État | Résumé |
|---|---|---|
| 0. Audit | ✅ | `AUDIT_NABUINVENT.md` : causes exactes des deux bugs Android identifiées |
| 1. JSON brut + défilement | ✅ | Décodage tolérant, fiches structurées, défilement libre ; vérifié sur le Honor |
| 2. Atelier / concepts | ✅ | Concepts par objet (3 variantes), mode ressources, onglet Atelier ; vérifié sur le Honor avec Claude |
| 3. Photo des matériaux | ✅ | Analyse multimodale réelle + consentement + correction ; analyse réelle à valider avec une vraie photo |
| 4. Concepteur technique | ⬜ | |
| 5. Studio visuel | ⬜ | |
| 6. Mémoire du projet | ⬜ | |
| 7. Fabrication guidée | ⬜ | |
| 8. Sécurité | ⬜ | |
| 9. Exports | ⬜ | |
| 10. Design | ⬜ | |
| 11–12. Qualité, tests, livraison | ⬜ | |

## Journal

### Phase 0 — Audit
- Fichier : `AUDIT_NABUINVENT.md`.
- Bug JSON : `max_tokens` 1800 tronque les réponses, `parse` affiche alors le texte brut.
- Bug défilement : écouteur qui relance `animateTo(bas)` à chaque notification près du bas.

### Phase 1 — JSON brut et défilement
**JSON brut**
- `lib/ai/lenient_json.dart` : extraction d'un objet JSON entouré de texte ou de blocs ```json,
  suppression des virgules finales, **réparation des réponses tronquées** (coupe à la dernière
  valeur complète puis fermeture des chaînes/tableaux/objets).
- `NabuAiResponse.parse` ne renvoie plus jamais le JSON comme message : message extrait ou
  explication ; texte d'origine conservé dans `raw` (secrets masqués, `lib/ai/redact.dart`) ;
  indicateur `partial`.
- `max_tokens` porté de 1 800 à 4 096 (`OpenAICompatibleProvider.maxOutputTokens`).
- `lib/ai/display_reply.dart` : chaque bulle est construite à partir de données interprétées ;
  les anciennes réponses brutes déjà enregistrées sont ré-interprétées à l'affichage.
- `lib/widgets/rich_message.dart` : titres, paragraphes, listes, gras, code.
- `lib/widgets/invention_sections.dart` : `InventionResultCard`, `MaterialsSection`,
  `ToolsSection`, `BudgetSection`, `ConstructionSteps`, `SafetyWarnings` (sections repliables,
  copie de la fiche) ; `lib/export/project_text.dart` (version texte).
- Réglage **Mode technique** (Réglages → Avancé) : JSON d'origine, clés masquées, copiable.

**Défilement**
- Suppression de l'écouteur qui ramenait en bas à chaque notification.
- Défilement automatique seulement si l'utilisateur est déjà en bas (ou vient d'envoyer) ;
  la réponse s'affiche à partir de son début ; clavier géré.
- Bouton « Dernier message ». Un seul défilement vertical, aucune bulle à défilement interne ;
  sélection tactile par `SelectionArea`.

**Contrôles** : `flutter analyze` OK ; 51 tests (dont défilement à 5 000 / 20 000 / 50 000
caractères, réponse tronquée à n'importe quel endroit, ancienne réponse brute) ; APK release
installé sur le Honor : la vraie réponse tronquée de l'utilisateur s'affiche en fiche, trois
gestes vers le haut remontent sans retour automatique.

Incident : le keystore avait été déplacé dans `~/Documents/key_mise a jour nabuinvent/keystores/` ;
empreinte vérifiée identique (SHA-256 5F:D8:FA:32…), `android/key.properties` mis à jour.

### Phase 2 — Atelier d'invention
- Contrat IA : intent `concepts`, champs `concepts` (objet, nom, description, style, matériaux,
  dimensions indicatives, difficulté, temps, budget, avantages, contraintes, `why`,
  `feasibility`) et `resources`. Prompt : jusqu'à 3 variantes réellement différentes par objet,
  mode ressources, règles d'honnêteté (mesures = estimations) et de sécurité.
- `lib/models/concept.dart` (`InventionConcept`, regroupement par objet, `toProject()`).
- `lib/ai/offline_atelier.dart` : analyse de la demande (objets, matériaux, destination ;
  ressources), 3 variantes types (rustique / articulée / stylisée) et idées classées par
  faisabilité selon les ressources. Message explicite « Atelier local : modèles types ».
- `AppState` : `adoptConcept`, indicateur `aiThinking` (demandes lancées depuis n'importe quel
  écran), historique envoyé au modèle enrichi de la liste numérotée des concepts.
- Interface : `ConceptGalleryCard` / `ConceptTile` dans le Studio ; choix → développement par
  l'IA (cloud) ou projet créé directement (local). Nouvel onglet **Atelier**
  (`lib/screens/atelier_screen.dart`) : idée → concepts, « Avec ce que j'ai », photo, galerie de
  concepts, Étincelles (déplacées dans l'Atelier).
- Vérifié sur le Honor : l'exemple « canard et héron en boîtes de conserve » envoyé depuis
  l'Atelier produit une galerie Canard / Héron (Claude), dimensions marquées « indicatif ».

### Phase 3 — Photo des matériaux
- `VisionProvider` (interface) ; `OpenAICompatibleProvider.analyzeMaterials` envoie l'image en
  `image_url` base64 (format OpenAI, accepté par Anthropic, Gemini, OpenRouter, Mistral).
- `lib/models/material_analysis.dart` : éléments reconnus (nom, matériau, quantité, confiance),
  questions sur les informations manquantes ; le prompt interdit de donner des dimensions.
- `lib/screens/photo_materials_screen.dart` : appareil photo / galerie (`image_picker`, image
  réduite à 1 600 px, sans permission de stockage), **consentement** avant envoi (mémorisable
  par fournisseur), correction / ajout / suppression des éléments, saisie des quantités et
  dimensions, puis « Proposer des créations » (mode ressources du Studio).
- Mode local ou cloud non configuré : fonction affichée comme **non disponible**, jamais simulée.
- Erreurs : réseau, délai, modèle sans vision (message dédié).
- Tests : requête multimodale vérifiée avec un client HTTP simulé. Écran vérifié sur le Honor ;
  l'analyse d'une vraie photo reste à valider par l'utilisateur.

**Contrôles** : `flutter analyze` OK ; 63 tests.
