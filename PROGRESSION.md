# Progression — Atelier d'invention NabuInvent AI

Branche de travail : `atelier-invention` (créée depuis `release-1.0.3`).

| Phase | État | Résumé |
|---|---|---|
| 0. Audit | ✅ | `AUDIT_NABUINVENT.md` : causes exactes des deux bugs Android identifiées |
| 1. JSON brut + défilement | ✅ | Décodage tolérant, fiches structurées, défilement libre ; vérifié sur le Honor |
| 2. Atelier / concepts | ⏳ | |
| 3. Photo des matériaux | ⬜ | |
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
