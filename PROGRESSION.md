# Progression — Atelier d'invention NabuInvent AI

Branche de travail : `atelier-invention` (créée depuis `release-1.0.3`).

| Phase | État | Résumé |
|---|---|---|
| 0. Audit | ✅ | `AUDIT_NABUINVENT.md` : causes exactes des deux bugs Android identifiées |
| 1. JSON brut + défilement | ✅ | Décodage tolérant, fiches structurées, défilement libre ; vérifié sur le Honor |
| 2. Atelier / concepts | ✅ | Concepts par objet (3 variantes), mode ressources, onglet Atelier ; vérifié sur le Honor avec Claude |
| 3. Photo des matériaux | ✅ | Analyse multimodale réelle + consentement + correction ; analyse réelle à valider avec une vraie photo |
| 4. Concepteur technique | ✅ | Fiche avec provenance des données, calculateur testé, plans calculés ; vérifié sur le Honor |
| 5. Studio visuel | ✅ | Vrai fournisseur /images/generations, styles, modifications, versions ; « non configuré » sinon |
| 6. Mémoire du projet | ✅ | Versions restaurables, contraintes mémorisées, références « le deuxième » |
| 7. Fabrication guidée | ✅ | « On le fabrique ! » : étape par page, progression, aide IA |
| 8. Sécurité | ✅ | Contrôles déterministes, validation professionnelle signalée |
| 9. Exports | ✅ | PDF, PNG, JSON, ZIP ; sélecteur Android sans permission ; vérifié sur le Honor |
| 10. Design | ✅ | Teintes cuivre/bronze, onglet Atelier, cartes repliables, typographie |
| 11–12. Qualité, tests, livraison | ✅ | Annulation des requêtes, 84 tests, documentation, APK 1.1.0, archive des sources |

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

### Phase 4 — Concepteur technique
- `lib/models/tech_sheet.dart` : pièces (forme, **orientation**, quantité, cotes en mm, position,
  fixation, prix), dimensions d'ensemble, fixations, finitions, précautions, inconnues.
  Chaque donnée porte sa **provenance** : mesure utilisateur / hypothèse IA / calculé / inconnu.
- État du plan **calculé** (jamais déclaré par l'IA) : incomplet (cotes manquantes) → indicatif
  (hypothèses) → cotes vérifiées par l'utilisateur.
- Fusion d'une proposition IA : **une mesure de l'utilisateur n'est jamais écrasée**.
- `lib/tech/material_calculator.dart` (fonctions pures testées) : plan de découpe des barres
  (premier ajustement décroissant, trait de scie, chutes, pièces trop longues), surfaces,
  volumes, tôle de conserves, budget avec pièces non chiffrées.
- `lib/widgets/tech_drawings.dart` : vues face / profil / dessus / éclatée / assemblage
  numéroté et plan de découpe, calculés à partir des cotes (filigrane « PLAN INDICATIF »).
- Contrat IA `techsheet` ; moteur local : fiche construite depuis les matériaux, **cotes
  inconnues** (`lib/tech/tech_sheet_builder.dart`).
- `lib/screens/technical_screen.dart` : Fiche / Pièces / Plans, saisie des mesures,
  suppression de la fiche.

### Phase 5 — Studio visuel
- `lib/ai/image_generator.dart` : client `/images/generations` (b64 ou URL, retrait des
  paramètres refusés), styles Réaliste, Rustique, Industriel, Fantaisiste, Artistique,
  Minimaliste, prompt construit à partir du projet et de ses contraintes.
- Réglages → Génération d'images (URL, modèle, clé chiffrée). Sans service : « non configurée ».
- `lib/screens/visual_studio_screen.dart` : confirmation du coût, modifications en langage
  naturel (notées dans le projet), versions conservées, rappel aperçu ≠ plan.

### Phase 6 — Mémoire du projet
- Instantané avant chaque modification par l'IA (plan, mise à jour, fiche technique,
  suppression de fiche) ; restauration qui conserve l'état courant (`VersionsScreen`).
- Contraintes exprimées sur le projet actif mémorisées (`designNotes`) et envoyées à l'IA.
- Références aux concepts : liste numérotée transmise au modèle ; en local, « le deuxième me
  plaît » crée directement le projet correspondant.

### Phase 7 — « On le fabrique ! »
- `lib/screens/build_mode_screen.dart` : objectif, matériaux, outils, instructions, cotes,
  conseils, précautions, case Terminé, progression et étape courante sauvegardées ; aide
  « plus simplement », « sans cet outil », « autre méthode », « pourquoi ? ».

### Phase 8 — Sécurité
- `lib/tech/safety_checker.dart` : bords coupants, récipients réutilisés, corrosion, humidité,
  eau stagnante, stabilité, charge humaine et 230 V (validation professionnelle), électricité,
  produits chimiques, soudure, outils, enfants ; avertissement « ne garantit pas la sécurité ».

### Phase 9 — Exports
- `lib/export/project_exporter.dart` : PDF (police DejaVu embarquée pour ≈ × € œ), PNG des
  vues et découpes rendus hors écran, JSON structuré (projet + calculs + sécurité,
  réimportable), ZIP complet. `lib/screens/export_screen.dart` : Enregistrer (sélecteur
  Android, aucune permission) ou Partager. Tout fonctionne hors ligne.

### Phase 10 — Design
- Teintes Cuivre et Bronze (Cuivre par défaut pour les nouvelles installations), titres
  renforcés, bannière d'atelier, cartes et sections repliables, onglet Atelier.

**Contrôles** : `flutter analyze` OK ; 83 tests ; vérifié sur le Honor : conception technique,
plan dessiné (900 × 18 mm), export PDF/ZIP/JSON/PNG, sélecteur d'enregistrement Android.
Bugs trouvés en route et corrigés : orientation des pièces dans les vues, titre de sécurité
qui débordait, badge « Mesure utilisateur » sur une pièce sans cote, onglet tronqué.

### Phases 11–12 — Qualité et livraison
- Annulation réelle des requêtes (`http.AbortableRequest`, bouton « Annuler » du Studio) ;
  une seule demande à la fois depuis l'Atelier ; coût des images confirmé avant génération.
- Version 1.1.0+5. Documentation : `README.md`, `GUIDE_UTILISATEUR.md` (mode d'emploi réécrit),
  `FONCTIONNALITES.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `RAPPORT_TESTS.md`.
- Livrables dans `livraison/` (non suivi par git) : APK release signé, archive ZIP des sources.
- Pas de `.deb` : cible Linux non configurée (documenté).
