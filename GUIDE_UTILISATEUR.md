# Mode d'emploi — NabuInvent AI 1.1

NabuInvent est votre compagnon d'invention : on lui décrit une idée, il propose des concepts,
les transforme en projet, établit la fiche technique et les plans, guide la fabrication et
produit un dossier exportable.

## 1. Premier démarrage

Un écran de bienvenue présente l'application. Elle fonctionne **tout de suite, hors ligne**,
grâce à son moteur local. Pour des propositions sur mesure, l'analyse de photos et les
aperçus visuels, configurez un fournisseur cloud (voir § 9).

## 2. Les 5 onglets

| Onglet | Rôle |
|---|---|
| Accueil | Statistiques, projets récents, journal |
| Projets | Toutes vos inventions (filtres, recherche, favoris) |
| Studio | La conversation avec l'agent : une seule mémoire pour toutes vos demandes |
| Atelier | Idée → concepts, « avec ce que j'ai », photo, galerie de concepts, étincelles |
| Réglages | Moteur d'IA, génération d'images, apparence, mode technique, sauvegardes |

## 3. Du rêve aux concepts (Atelier)

1. Onglet **Atelier** → « Une idée à fabriquer ». Écrivez par exemple :
   *« Je voudrais fabriquer un canard et un héron avec des boîtes de conserve pour décorer
   mon jardin. »*
2. **Proposer des concepts** : le Studio s'ouvre et l'agent propose, **pour chaque objet**,
   jusqu'à trois variantes réellement différentes (style, matériaux, dimensions indicatives,
   difficulté, temps, budget, avantages, contraintes).
3. **Choisir ce concept** : il devient un projet. En mode cloud, l'agent le développe en fiche
   complète. Vous pouvez aussi écrire simplement *« le deuxième me plaît »*.

**Avec ce que j'ai** : listez vos ressources (« 4 boîtes de conserve », « fil de fer »…).
L'inventeur autonome classe les idées selon ce que vous possédez déjà et explique ses choix.

> Les dimensions proposées sont des **ordres de grandeur** : elles sont marquées « indicatif »
> et ne remplacent pas vos mesures.

## 4. Qu'est-ce que je peux fabriquer avec ça ? (photo)

*Nécessite le mode cloud avec un modèle capable de lire les images (Claude, GPT-4o, Gemini…).*

1. Atelier → **Qu'est-ce que je peux fabriquer avec ça ?**
2. **Appareil photo** ou **Galerie** : photographiez vos matériaux, bien éclairés.
3. **Analyser la photo** : une confirmation vous rappelle que la photo est envoyée à votre
   fournisseur IA (vous pouvez mémoriser votre accord).
4. Corrigez la liste reconnue, ajoutez les quantités et **mesurez les dimensions** (l'IA ne
   mesure pas sur une photo).
5. **Proposer des créations** : les idées arrivent dans le Studio.

En mode local, cette fonction est indiquée comme indisponible : elle n'est jamais simulée.

## 5. Le Studio

- Les réponses s'affichent en **fiches lisibles** : matériaux, outils, budget, durée,
  difficulté, étapes, précautions. Les sections se replient, la fiche se copie (icône copie),
  le texte se sélectionne par appui long.
- Remontez librement dans la conversation ; le bouton **Dernier message** ramène en bas.
- **Annuler** (à côté de l'indicateur de réflexion) interrompt une demande trop longue.
- **Continuer sur ce projet** épingle un projet : vos demandes s'y rapportent. Les contraintes
  que vous exprimez (« je n'ai que quatre boîtes », « je veux éviter la soudure ») sont
  **mémorisées** dans le projet et transmises à chaque demande.

## 6. Le projet et son atelier

Ouvrez un projet (onglet Projets) ; la section **Atelier du projet** regroupe :

### Conception technique
- **Fiche** : objectif, dimensions d'ensemble, fixations, finitions, précautions, inconnues.
- **Pièces** : nomenclature. Touchez une pièce pour saisir **vos mesures** (mm), sa forme et
  son orientation. Chaque cote affiche son origine : *Mesure utilisateur*, *Hypothèse IA*,
  *Calculé* ou *Inconnu*. Les quantités, longueurs, surfaces, le **plan de découpe** des barres
  (chutes comprises) et le budget sont **calculés par l'application**.
- **Plans** : vues de face, profil, dessus, éclatée et d'assemblage numérotée, dessinées à
  partir des cotes. Le bandeau indique si le plan est *incomplet*, *indicatif* (hypothèses à
  vérifier) ou si *toutes les cotes viennent de vos mesures*.
- **Proposer une fiche avec l'IA** (cloud) ou **Partir des matériaux** (cotes à saisir).
  Une nouvelle proposition de l'IA ne remplace jamais vos mesures.

### On le fabrique !
Une étape par page : objectif, matériaux, outils, instructions, cotes, conseils, précautions
et case **Terminé**. La progression est enregistrée. Boutons d'aide : *Plus simplement*,
*Sans cet outil*, *Autre méthode*, *Pourquoi ?*

### Studio visuel
Aperçus artistiques du projet terminé (Réaliste, Rustique, Industriel, Fantaisiste,
Artistique, Minimaliste), puis modifications en langage naturel (*« allonge le cou du
héron »*). Chaque version est conservée. Un aperçu sert à **visualiser** ; pour fabriquer,
utilisez les plans. Nécessite un service d'images configuré (§ 9) ; chaque image est facturée
par le fournisseur, une confirmation est demandée.

### Versions et contraintes
Une copie du projet est enregistrée avant chaque modification par l'IA. **Restaurer** une
version conserve l'état actuel dans l'historique.

### Exporter
**Préparer le dossier**, puis pour chaque fichier **Enregistrer** (choix du dossier Android,
sans permission de stockage) ou **Partager** :
- **PDF** : fiche, nomenclature, calculs, étapes, sécurité, schémas, aperçu ;
- **ZIP** : tous les fichiers du projet ;
- **JSON** : données complètes et calculs ;
- **PNG** : chaque schéma technique.

## 7. Sécurité

Chaque fiche affiche des **conseils et précautions** calculés à partir des matériaux et de
l'usage : bords coupants des boîtes (ébavurer, gants), récipients ayant contenu des produits
dangereux (à proscrire), corrosion et humidité à l'extérieur, stabilité, électricité,
produits chimiques, soudure, outils. Les projets qui portent une personne ou utilisent le
230 V sont signalés comme nécessitant une **validation professionnelle**. Ces rappels ne
garantissent pas la sécurité d'un assemblage.

## 8. Étincelles, réserve d'idées, journal

- **Étincelles** (Atelier → Étincelles) : combinaisons créatives au hasard (12 par jour en
  local), à garder ou transformer en invention.
- **Réserve d'idées** et **Journal** : comme avant, depuis l'Accueil et la fiche projet.

## 9. Réglages

1. **Assistant IA** : *Mode local* ou *Mode cloud*. En cloud, choisissez un préréglage
   (OpenAI, OpenRouter, Mistral, Groq, Perplexity, Anthropic, Gemini), collez votre clé et
   **Testez la connexion** : en cas d'échec, le message exact du fournisseur s'affiche.
2. **Génération d'images** : service compatible « /images/generations » (ex. OpenAI
   `gpt-image-1`) avec sa propre clé. Anthropic (Claude) ne génère pas d'images.
3. **Apparence** : thème clair/sombre/système, 12 couleurs dont Cuivre et Bronze.
4. **Avancé → Mode technique** : affiche sous chaque réponse le JSON d'origine (clés masquées).
5. **Données** : exporter / importer une sauvegarde complète, tout réinitialiser.

> 🔒 Les clés API sont chiffrées sur l'appareil (Keystore Android) et exclues des sauvegardes
> Android. Les URL doivent commencer par `https://`.

## 10. Hors ligne

Vos projets, fiches, plans, calculs, la fabrication guidée et les exports fonctionnent sans
réseau. Le badge du Studio indique le mode ; les fonctions qui ont besoin d'Internet (cloud,
photo, images) le disent clairement.

## 11. Dépannage

| Problème | Solution |
|---|---|
| Le Studio ne répond pas | Réglages → Tester la connexion : le message du fournisseur indique la cause (clé, modèle, crédits). |
| « Modèle introuvable » | Vérifiez le nom exact du modèle dans la documentation du fournisseur. |
| Réponse marquée « incomplète » | Le modèle a été coupé ; reformulez ou demandez la suite. |
| Analyse de photo indisponible | Passez en mode cloud avec un modèle multimodal. |
| Studio visuel désactivé | Configurez Réglages → Génération d'images. |
| Plan « incomplet » | Saisissez les cotes manquantes dans l'onglet Pièces. |
| Changement de téléphone | Réglages → Exporter une sauvegarde, puis Importer sur le nouveau. |
