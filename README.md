# NabuInvent AI

**NabuInvent AI** est un assistant IA inventeur, bricoleur et créatif pour Android.
Il vous aide à imaginer, concevoir et planifier des inventions, à trouver des étincelles
de créativité, à évaluer vos idées et à tenir un journal de bord. 100 % français.

Le cœur de l'application fonctionne **entièrement hors ligne** grâce à un moteur
local intégré (aucune donnée envoyée à un serveur). Vous pouvez, en option, connecter
n'importe quel service compatible **OpenAI** (OpenAI, OpenRouter, Mistral, Groq,
Perplexity, Claude, Gemini…) pour obtenir des réponses générées par un grand modèle de langage.

---

## Installation

Installez l'APK de la dernière version (voir le dossier de livraison).
Activez « installer des applications inconnues » si nécessaire.

> ⚠️ À partir de la **1.0.3**, les APK sont signés avec la clé release de
> NabuInvent. Une version antérieure (signée debug) doit être **désinstallée**
> avant d'installer la 1.0.3 : exportez d'abord vos données (Réglages →
> Exporter), puis réimportez-les. Les mises à jour suivantes s'installent
> par-dessus, sans perte.

## Démarrage rapide

1. Ouvrez **NabuInvent AI** — un petit écran de bienvenue explique les bases.
2. Allez dans l'onglet **Studio** (💬) et écrivez une phrase, par exemple :
   - *« Invente-moi un objet pour organiser mon bureau »*
   - *« Donne-moi une idée intelligente pour le jardin »*
   - *« Écris-moi une idée facile à réaliser »*
   - *« Comment dois-je nommer une invention qui… ? »*
3. L'IA crée automatiquement une **fiche projet**, que vous retrouvez dans **Projets**.
4. Depuis une fiche projet, demandez un **plan de construction** détaillé,
   cochez les étapes au fur et à mesure dans l'onglet **Plan**.
5. Retrouvez vos trouvailles aléatoires dans l'onglet **Étincelles** (12 gratuites
   par jour en mode local) et vos idées en attente dans **Réserve d'idées** (📋).

## Personnalisation optionnelle

Ouvrez **Réglages** pour :

- Choisir **Local (hors ligne)** ou **Cloud (OpenAI)** comme moteur d'IA.
- En mode Cloud : saisir l'**URL de base**, la **clé API** et le **modèle**
  (des préréglages existent pour OpenAI, OpenRouter, Mistral, Groq, Perplexity,
  Claude et Gemini).
- Tester la connexion avant de l'utiliser.
- Changer la **couleur d'accent** et le **thème clair/sombre**.
- **Exporter** / **Importer** une sauvegarde JSON de toutes vos données.

## Construire depuis les sources

Prérequis : Flutter 3.44+ (Dart 3.12+), SDK Android.

```bash
export PATH="$PATH:/opt/flutter/bin"   # selon votre installation
cd nabuinvent
flutter pub get
flutter analyze        # doit afficher « No issues found! »
flutter test           # les 34 tests unitaires doivent passer
flutter build apk --release
flutter build apk --release --split-per-abi
```

Les APK sont produits dans `build/app/outputs/flutter-apk/`.
La version est gérée dans `pubspec.yaml` (`1.0.3+4`) : augmentez le numéro
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