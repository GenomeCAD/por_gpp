# Portails - Gestionnaire des Processus Projets (GIP CAD)

## Vue d'ensemble

Le Gestionnaire des Processus Projets (GPP) est un fork du code open source de [démarche numérique](https://github.com/demarche-numerique/demarche.numerique.gouv.fr) (anciennement demarches-simplifiees.fr), transformé pour répondre aux besoins du GIP CAD. Le code d'origine, conçu comme une plateforme généraliste de dépôt et d'instruction de démarches administratives, est remanié pour servir un objectif spécifique : l'instruction des dossiers de candidature déposés sur la plateforme publique nationale.

Le GPP ne gère pas le dépôt des dossiers par les usagers. Il se connecte à [demarche.numerique.gouv.fr](https://demarche.numerique.gouv.fr/) via son API GraphQL pour récupérer les dossiers déposés, puis offre aux instructeurs du GIP CAD un environnement d'instruction dédié avec des outils spécifiques : checklist de vérification, notes et pièces jointes par champ, et gestion du calendrier CSE.

L'architecture du GPP, ses échanges avec la plateforme publique et les évolutions proposées sont décrits dans [ARCHITECTURE.md](ARCHITECTURE.md) ; les limites actuelles sont résumées plus bas, dans « Limites connues ».

---

## Installation

### Dépendances techniques

- **PostgreSQL** (version >= 15)
- **Redis** (utilisé par Kredis, et comme cache quand `REDIS_CACHE_URL` est renseignée ; les jobs, eux, passent par delayed_job, voir « Configuration »)
- **rbenv** : voir https://github.com/rbenv/rbenv-installer#rbenv-installer--doctor-scripts
- **Bun** : voir https://bun.sh/docs/installation
- **imagemagick** et **gsfonts** pour générer les filigranes sur les titres d'identité et les miniatures d'images

> [!WARNING]
> Pensez à restreindre la policy d'ImageMagick pour bloquer l'exploitation d'images malveillantes.
> La configuration par défaut est généralement insuffisante pour des images provenant du web.
> Par exemple sous debian/ubuntu dans `/etc/ImageMagick-6/policy.xml` :

```xml
<!-- en plus de la policy par défaut, ajoutez à la fin du fichier -->
<policymap>
    <policy domain="coder" rights="none" pattern="*"/>
    <policy domain="coder" rights="read | write" pattern="{JPG,JPEG,PNG,JSON}"/>
    <policy domain="module" rights="none" pattern="{MSL,MVG,PS,SVG,URL,XPS}"/>
</policymap>
```

Pour les tests : **Chrome** et **chromedriver** (voir https://developer.chrome.com/blog/chrome-for-testing).

### Création des rôles de la base de données

Les informations nécessaires à l'initialisation de la base doivent être pré-configurées à la main :

    su - postgres
    psql
    > create user gpp_development with password 'gpp_development' superuser;
    > create user gpp_test with password 'gpp_test' superuser;
    > \q

Sous Ubuntu, certains packages doivent être installés au préalable :

    sudo apt-get install libcurl3 libcurl3-gnutls libcurl4-openssl-dev libcurl4-gnutls-dev zlib1g-dev

### Initialisation de l'environnement

Exécutez la commande suivante pour créer la base de données, installer les dépendances et préparer l'environnement :

    bin/setup

### Configuration

Le GPP se configure via le fichier `.env` à la racine du projet (voir `config/env.example` pour la liste complète). Les variables ci-dessous n'y figurent pas : les ajouter au `.env`.

| Variable | Description |
|----------|-------------|
| `PUBLIC_DS_API_URL` | URL de l'instance publique (ex : `https://demarche.numerique.gouv.fr`). Lue au moment de la liaison d'une démarche et conservée dans la liaison. Si la variable est absente, `https://www.demarches-simplifiees.fr`, ancienne adresse de la plateforme ; vide, elle n'est pas remplacée par cette adresse et la liaison échoue (« Erreur lors de la liaison ») |
| `PUBLIC_DS_API_TOKEN` | Token API généré sur l'instance publique, pour authentifier les appels GraphQL. Lu à chaque synchronisation |
| `RAILS_QUEUE_ADAPTER` | `delayed_job`. Obligatoire en production, où la valeur par défaut est Sidekiq ; en développement, sans elle, les jobs tournent dans le processus web (adaptateur `async`) et le worker lancé par `bin/dev` ne sert pas |
| `APPLICATION_NAME` | Nom affiché dans l'en-tête (par défaut : `Gestionnaire des Processus Projets`) |

---

## Lancement de l'application

```bash
bin/dev
```

L'application est accessible à l'adresse http://localhost:3000 avec en parallèle un worker delayed_job pour les jobs (avec `RAILS_QUEUE_ADAPTER=delayed_job`, voir « Configuration ») et le bundler Vite.

Pour lancer uniquement le serveur Rails (sans worker ni Vite) :

```bash
bin/rails server
```

Le port peut être modifié avec l'option `-p` :

```bash
bin/rails server -p 3001
```

### Utilisateurs de test

En local, un utilisateur de test est créé automatiquement par `bin/setup`, avec les identifiants `test@exemple.fr` / `this is a very complicated password !` (voir [db/seeds.rb](db/seeds.rb)).

### Emails envoyés en local

Ouvrez la page http://localhost:3000/letter_opener.

### Mise à jour

Pour mettre à jour l'environnement de développement, installer les nouvelles dépendances et exécuter les migrations :

    bin/update

---

## Prérequis côté plateforme publique

L'instance publique demarche.numerique.gouv.fr est un service existant, administré indépendamment. Côté public, il suffit de :

1. **Disposer d'un compte administrateur** sur demarche.numerique.gouv.fr
2. **Créer et publier une démarche** avec le formulaire destiné aux usagers
3. **Générer un token API** (menu « Mon profil », carte « Jetons d'identification de l'API (token) », bouton « Créer un nouveau jeton », en lecture seule) : ce token sera utilisé par le GPP pour interroger l'API GraphQL. La carte « Jetons API » des paramètres de la démarche sert à API Entreprise et API Particulier, pas à ce token. Limiter le jeton à la démarche liée, au réseau du GPP et dans le temps (voir ARCHITECTURE.md, section 7).
4. **Ajouter comme instructeurs de la démarche publique** les agents du GIP CAD qui instruisent dans le GPP : le GPP ne recopie ni les réponses au formulaire ni les pièces jointes, que les agents lisent sur la plateforme publique.

Pour tester sans compte sur l'instance publique, [DOCKER-SETUP.md](DOCKER-SETUP.md) décrit un environnement local à deux instances : le GPP et une instance Démarches Simplifiées qui joue le rôle de la plateforme publique, toutes deux sous Docker (fichiers de l'instance dans `docker/public-ds/`).

---

## Workflow complet

### 1. Créer une démarche d'instruction sur le GPP

Sur le GPP, un administrateur crée une démarche qui servira de support à l'instruction :

1. Se connecter en tant qu'administrateur
2. Créer une nouvelle démarche
3. Configurer les champs du formulaire comme des **critères de vérification** : typiquement des champs Oui/Non correspondant aux points de contrôle que l'instructeur devra valider (ex : « Identité du demandeur vérifiée », « Données demandées existent dans l'EDS »)
4. Publier la démarche

### 2. Lier la démarche GPP à la démarche publique

Sur la page de gestion de la démarche (`/admin/procedures/N`), un bloc « Liaison avec la démarche publique » apparaît en haut de la page :

1. Saisir le **numéro de la démarche publique** correspondante sur demarche.numerique.gouv.fr
2. Cliquer « Lier »

Cela crée une association (`ProcedureMirror`) entre la démarche locale et la démarche publique ; l'adresse de l'instance publique est celle de `PUBLIC_DS_API_URL` au moment de la liaison. Un lien « (voir) » permet de naviguer directement vers la démarche sur l'instance publique. La liaison peut être supprimée à tout moment via le bouton « Délier ».

Une démarche publique ne doit être liée qu'à une seule démarche du GPP : rien ne l'empêche aujourd'hui (voir « Limites connues »).

### 3. Les usagers déposent leurs dossiers sur la plateforme publique

Les demandeurs accèdent à la démarche sur demarche.numerique.gouv.fr, remplissent le formulaire et déposent leur dossier. Cette étape est entièrement gérée par la plateforme publique ; le GPP n'intervient pas.

### 4. Synchroniser les dossiers

La synchronisation peut être déclenchée de deux manières :

- **Manuellement** : sur la page de suivi des dossiers (`/procedures/N/tous`), un bouton « Synchroniser » apparaît dans l'en-tête. Un bouton équivalent est aussi disponible sur la page de configuration de synchronisation de la démarche (Administration).
- **Automatiquement** : sur la page de gestion de la démarche, le bouton « Synchronisation auto. » permet de configurer une fréquence de synchronisation périodique (en minutes, heures ou jours).

La synchronisation utilise l'API GraphQL (`PublicDossierSyncService`) :

- **Nouveaux dossiers** : un dossier local est créé en état « en instruction », au nom d'un compte technique (`system@gipcad.local`), avec la civilité, le nom et le prénom du demandeur et l'email du compte qui a déposé le dossier. Un `LinkedDossier` conserve le lien vers le dossier public (numéro, URL, état). La date de dépôt du dossier local est celle de cette première synchronisation (voir « Limites connues »).
- **Dossiers existants** : l'état du dossier public est mis à jour si nécessaire.

### 5. Instruire un dossier

L'instructeur ouvre un dossier synchronisé. La page du dossier présente plusieurs blocs :

#### Bloc « Dossier lié »
- Lien vers le dossier sur la plateforme publique, dans un nouvel onglet (voir « Limites connues »)
- Badge d'état du dossier public (en construction, en instruction, accepté, etc.)
- Identité du demandeur : civilité, prénom, nom, et adresse email du compte qui a déposé le dossier

#### Bloc « Vérifications du dossier » (checklist)
Les champs Oui/Non définis dans la démarche GPP sont présentés comme une checklist :

- L'instructeur coche Oui ou Non pour chaque critère de contrôle
- Sous chaque champ, il peut ajouter une **note** (texte libre, sauvegarde automatique) pour justifier sa décision
- Il peut joindre des **pièces justificatives** à chaque note (fichiers téléversés, supprimables individuellement)

#### Contrainte de validation
Le bouton « Accepter » dans le menu d'instruction est **désactivé** tant que tous les champs Oui/Non ne sont pas cochés « Oui ». Un tooltip explique cette contrainte. Les actions « Classer sans suite » et « Refuser » restent disponibles à tout moment.

#### Vue lecture seule
Une fois le dossier terminé (accepté, refusé ou classé sans suite), les vérifications, notes et pièces jointes sont affichées en lecture seule dans le récapitulatif.

---

## Tableau de suivi des dossiers

Le tableau des dossiers affiche par défaut les colonnes suivantes :

| Colonne | Description |
|---------|-------------|
| N° dossier | Numéro du dossier local |
| Demandeur | Email du compte qui a déposé le dossier sur la plateforme publique |
| Date de dépôt | Date de la première synchronisation du dossier, et non sa date de dépôt sur la plateforme publique (voir « Limites connues ») |
| N° dossier lié | Numéro du dossier public (lien cliquable vers demarche.numerique.gouv.fr) |
| État du dossier lié | État actuel du dossier sur la plateforme publique |

Le tableau est trié par date de dépôt (du plus ancien au plus récent) par défaut.

---

## Module Calendrier CSE

Les dossiers déposés sont examinés lors des séances mensuelles du Comité Scientifique et Éthique (CSE). Un dossier doit être déposé **au moins 2 semaines avant la date du CSE** (T0 - 2 semaines) pour être étudié lors de cette session.

### Configuration (administrateur)

Sur la page de gestion de la démarche, le bouton « Calendrier CSE » (bloc « Autres paramètres ») mène à une page de configuration :

- Un **calendrier interactif** permet de sélectionner/désélectionner des dates en cliquant dessus
- La liste des dates sélectionnées s'affiche à droite avec la date limite de dépôt calculée automatiquement (T0 - 2 semaines)
- Bouton « Enregistrer » pour sauvegarder, « Annuler et revenir à l'écran de gestion » pour abandonner (avec confirmation)

### Affichage dans le tableau des dossiers (instructeur)

Lorsque le tableau est trié par date de dépôt, un **séparateur visuel** apparaît :

- Une barre bleue indique la date du prochain CSE et la date limite de dépôt correspondante
- Les dossiers dont la date de dépôt est **postérieure** à la date limite sont **grisés** (opacité réduite) : ils ne seront pas étudiés lors du prochain CSE
- Les autres apparaissent normalement : ils sont éligibles

Le séparateur n'apparaît que lorsque le tableau est trié par date de dépôt. La date de dépôt comparée est celle de la première synchronisation : un dossier déposé à temps sur la plateforme publique mais synchronisé après la date limite apparaît grisé (voir « Limites connues »).

---

## Limites connues

Les corrections proposées sont détaillées dans [ARCHITECTURE.md](ARCHITECTURE.md), sections 6.3 à 6.6 et 9.

- **Pagination de la synchronisation** : le curseur de page n'est pas transmis à l'API ; au-delà d'une page de dossiers sur la démarche publique, la synchronisation redemande sans fin la première page.
- **Date de dépôt** : c'est la date de la première synchronisation, et non la date de dépôt sur la plateforme publique ; la date limite du CSE s'y compare.
- **Unicité des liaisons** : rien n'empêche de lier une même démarche publique à deux démarches du GPP ; ses dossiers ne sont alors créés que dans celle qui se synchronise la première.
- **Lien vers le dossier public** : il pointe vers `<instance>/dossiers/<numéro>`, qui est, dans le code de démarche numérique, la page du porteur, ouverte au seul propriétaire du dossier et à ses invités ; la page d'un instructeur est `<instance>/procedures/<numéro de la démarche>/dossiers/<numéro>`. À vérifier sur la plateforme publique.
- **Colonne « Demandeur »** : elle affiche l'email du compte qui a déposé le dossier, mais son tri et son filtre portent sur le compte technique `system@gipcad.local`, le même pour tous les dossiers.
- **Pas de retour vers la plateforme publique** : la décision et les messages saisis dans le GPP n'y sont pas reportés ; le porteur n'en est pas informé par le GPP.
- **Erreurs de la synchronisation automatique** : elles ne sont écrites que dans le journal de l'application ; sans token, la synchronisation automatique ne fait rien, sans le signaler.
- **Tests** : le code propre au GPP (voir « Modèles de données ajoutés ») n'a pas encore de tests automatisés.

---

## Tests

Les tests ont besoin de leur propre base de données et certains d'entre eux utilisent Selenium pour s'exécuter dans un navigateur.

- Lancer tous les tests : `bin/rspec`
- Lancer un test en particulier : `bin/rspec file_path/file_name_spec.rb:line_number`
- Relancer uniquement les tests échoués : `bin/rspec --only-failures`
- Tests système avec navigateur visible : `NO_HEADLESS=1 bin/rspec spec/system`
- Afficher les logs JS de la console : `JS_LOG=debug,log,error bin/rspec spec/system`

### Linting

Faire tourner tous les linters : `bin/rake lint`

---

## Modèles de données ajoutés

| Modèle | Description |
|--------|-------------|
| `ProcedureMirror` | Associe une démarche GPP à une démarche publique (URL + numéro) |
| `LinkedDossier` | Lie un dossier local à un dossier public (numéro, URL, état, identité du demandeur) |
| `ChampNote` | Note de l'instructeur sur un champ de vérification (texte + pièces jointes) |
| `CseDate` | Date d'un CSE configurée pour une démarche |
