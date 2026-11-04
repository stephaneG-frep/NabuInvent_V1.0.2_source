# Rapport de tests — NabuInvent AI 1.1.0

Date : 3 novembre 2026 · Flutter (Dart 3.12) · Appareil : Honor MTN-NX1M, Android 16

## Contrôles automatiques

| Commande | Résultat |
|---|---|
| `flutter analyze` | No issues found! |
| `flutter test` | **84 tests, tous réussis** |
| `flutter build apk --release` | APK signé avec la clé release (certificat `CN=NabuInvent`) |

### Répartition

| Fichier | Tests | Couverture |
|---|---|---|
| `lenient_json_test.dart` | 12 | JSON entouré de texte / blocs ```json, virgules finales, **réponse tronquée à n'importe quel endroit** (coupe tous les 37 caractères), message jamais en JSON, clés masquées, anciennes réponses brutes, rendu Markdown léger |
| `studio_scroll_test.dart` | 5 | Défilement vers le haut avec des réponses de **5 000, 20 000 et 50 000 caractères**, aucun retour automatique, bouton « Dernier message », nouveau message sans saut pour qui relit, ancienne réponse JSON affichée en fiche |
| `atelier_test.dart` | 12 | Analyse « canard et héron », 3 variantes distinctes par objet, dimensions « indicatif », mode ressources classé par faisabilité, routes existantes inchangées, adoption d'un concept, « le deuxième » transmis au modèle, **requête multimodale** (image base64, HTTP simulé), demande d'idées après correction, aucune analyse simulée en local, galerie |
| `conception_test.dart` | 20 | Plan de découpe (premier ajustement décroissant, trait de scie, chutes, pièce trop longue), tôle de conserves, quantités/surfaces/volumes/budget, état du plan, **fusion sans écraser les mesures**, fiche sans IA sans cote inventée, réponse `techsheet`, projections des vues, règles de sécurité et validation professionnelle, contraintes mémorisées, versions et restauration, « le deuxième me plaît » en local, prompt d'aperçu, appel `/images/generations` avec paramètre refusé, exports **PDF / PNG / ZIP** réellement produits, JSON réimportable |
| `cancel_test.dart` | 1 | **Annulation** : la requête est interrompue en moins de 5 s, aucune réponse appliquée |
| `regression_test.dart` | 18 | Non-régression de l'audit 1.0.2 (intentions, parsing, projets non écrasés, plans cloud, historique) |
| `openai_provider_test.dart` | 4 | Retrait de `temperature`, `max_completion_tokens`, clé refusée, messages d'erreur |
| `storage_test.dart` | 4 | Écritures concurrentes, fichier corrompu + `.bak`, réinitialisation |
| `core_test.dart` | 8 | Moteur local, parsing, sérialisation |

## Vérifications sur le téléphone (Honor, APK release, données réelles conservées)

| Vérification | Résultat |
|---|---|
| Réponse réelle de Claude tronquée (JSON brut avant) | ✅ Affichée en fiche : étapes numérotées, encadré de précautions |
| Défilement : trois gestes vers le haut dans une grande bulle | ✅ Remonte, reste en place 3 s, bouton « Dernier message » |
| Atelier → « canard et héron » → Claude | ✅ Galerie Canard / Héron, faisabilité, dimensions « (indicatif) », boutons « Choisir » |
| Indicateur de réflexion pour une demande lancée depuis l'Atelier | ✅ |
| Écran photo en mode cloud | ✅ Affiché (analyse d'une vraie photo : **non testée**, voir ci-dessous) |
| Conception technique : fiche, pièce cotée, plan de face 900 × 18 mm | ✅ |
| Export : PDF, ZIP, JSON, 5 schémas PNG produits sur l'appareil | ✅ |
| Enregistrer : sélecteur Android (sans permission) | ✅ Ouvert puis annulé |
| Journal Android | ✅ Aucune erreur Flutter |

## Non vérifié / limites

- **Analyse d'une vraie photo** : nécessite de prendre ou choisir une photo sur le téléphone ;
  la requête est vérifiée par test (format `image_url` base64), la réponse réelle du
  fournisseur reste à valider par l'utilisateur.
- **Génération d'images réelle** : aucun service d'images n'est configuré sur l'appareil ;
  le client est vérifié par test HTTP simulé. Le Studio visuel affiche « non configurée ».
- **Mode « On le fabrique ! »** et **restauration de versions** : vérifiés par tests et par
  compilation, pas manipulés sur l'appareil (aucun projet avec plan sur le téléphone).
- **Paquet Linux .deb** : non produit — la cible Linux n'est pas configurée dans ce projet
  (Android uniquement).
- La saisie au clavier pilotée par `adb` est déformée par les suggestions du clavier : les
  tests de formulaires sur l'appareil se sont limités aux champs numériques.
