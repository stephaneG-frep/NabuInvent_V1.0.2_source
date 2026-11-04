# NabuInvent AI

**NabuInvent AI** est un compagnon d'invention pour Android, 100 % en français. On lui décrit
une idée — *« un canard et un héron en boîtes de conserve pour le jardin »* — et il propose
plusieurs concepts, transforme le concept choisi en projet, établit la fiche technique et les
plans cotés, guide la fabrication pas à pas et produit un dossier exportable (PDF, ZIP, JSON,
PNG).

Le cœur de l'application fonctionne **hors ligne** (moteur local, projets, calculs, plans,
exports). En option, un service compatible **OpenAI** (OpenAI, OpenRouter, Mistral, Groq,
Perplexity, Anthropic, Gemini…) apporte des concepts sur mesure et l'analyse de photos, et un
service `/images/generations` les aperçus visuels.

---

## Installation

Installez l'APK de la dernière version (voir le dossier de livraison).
Activez « installer des applications inconnues » si nécessaire.

> ⚠️ Depuis la **1.0.3**, les APK sont signés avec la clé release de NabuInvent. Une version
> antérieure (signée debug) doit être **désinstallée** une fois : exportez d'abord vos données
> (Réglages → Exporter), puis réimportez-les. Les mises à jour suivantes, dont la 1.1.0,
> s'installent par-dessus, sans perte.

## Démarrage rapide

1. Onglet **Atelier** → décrivez ce que vous voulez fabriquer → **Proposer des concepts**.
2. Dans le Studio, **choisissez un concept** : il devient un projet.
3. Fiche projet → **Atelier du projet** : conception technique (cotes, calculs, plans),
   **On le fabrique !**, Studio visuel, versions, export.

Le mode d'emploi complet est dans [`GUIDE_UTILISATEUR.md`](GUIDE_UTILISATEUR.md).

## Configuration optionnelle (Réglages)

- **Assistant IA** : local ou cloud (préréglages, clé chiffrée, test de connexion avec le
  message exact du fournisseur).
- **Génération d'images** : URL, modèle (ex. `gpt-image-1`) et clé distincte.
- **Apparence**, **mode technique** (JSON d'origine des réponses), **sauvegardes**.

## Construire depuis les sources

Prérequis : Flutter 3.44+ (Dart 3.12+), SDK Android.

```bash
export PATH="$PATH:/opt/flutter/bin"   # selon votre installation
cd nabuinvent
flutter pub get
flutter analyze        # doit afficher « No issues found! »
flutter test           # les 84 tests doivent passer
flutter build apk --release
flutter build apk --release --split-per-abi
```

Les APK sont produits dans `build/app/outputs/flutter-apk/`.
La version est gérée dans `pubspec.yaml` (`1.1.0+5`) : augmentez le numéro
après le `+` à chaque livraison.

### Signature

La release est signée par la clé décrite dans `android/key.properties`
(ignoré par git) :

```properties
storePassword=…
keyPassword=…
keyAlias=nabuinvent
storeFile=/chemin/absolu/vers/nabuinvent-release.jks
```

Sans ce fichier, `flutter build apk --release` échoue volontairement :
signer avec une clé debug rendrait les mises à jour impossibles sans
désinstallation. **Le keystore et son mot de passe doivent être sauvegardés
hors de la machine** : s'ils sont perdus, plus aucune mise à jour de
l'application installée n'est possible.

## Documentation

- [`FONCTIONNALITES.md`](FONCTIONNALITES.md) — tout ce que sait faire l'application.
- [`GUIDE_UTILISATEUR.md`](GUIDE_UTILISATEUR.md) — guide pas à pas pour l'utiliser.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — structure technique du code.
- [`AUDIT_NABUINVENT.md`](AUDIT_NABUINVENT.md) — audit de départ de l'atelier d'invention.
- [`PROGRESSION.md`](PROGRESSION.md) — avancement phase par phase.
- [`CHANGELOG.md`](CHANGELOG.md) — journal des modifications.
- [`RAPPORT_TESTS.md`](RAPPORT_TESTS.md) — tests automatisés et vérifications sur appareil.