---
category: "administrateur"
subcategory: "liaison"
slug: "obtenir-token-api"
locale: "fr"
keywords: "token, API, jeton, authentification, GraphQL, plateforme publique, configuration"
title: "Comment obtenir un token API sur la plateforme publique ?"
---

# Comment obtenir un token API sur la plateforme publique ?

Le GPP utilise l'API GraphQL de la plateforme publique pour synchroniser les dossiers. Cette connexion nécessite un **token API** (jeton d'authentification) généré sur [demarche.numerique.gouv.fr](https://demarche.numerique.gouv.fr/).

## Générer le token

1. Connectez-vous sur demarche.numerique.gouv.fr avec un compte **administrateur** de la démarche publique.
2. Ouvrez votre profil (menu **« Mon profil »**) et, dans la carte **« Jetons d'identification de l'API (token) »**, cliquez sur **« Créer un nouveau jeton »**. La carte « Jetons API » des paramètres de la démarche sert à API Entreprise et API Particulier, pas à ce token.
3. Donnez-lui un nom descriptif (par exemple : « GPP GIP CAD »).
4. Privilèges : choisissez la démarche concernée (ou « toutes mes démarches ») et **« de lire uniquement »** : le GPP ne fait que lire.
5. Sécurité : indiquez si possible les réseaux autorisés, puis une durée de validité (une durée infinie exige le filtrage réseau).
6. Copiez le token affiché : il ne sera plus visible par la suite.

## Configurer le token dans le GPP

Le token doit être renseigné dans la variable d'environnement `PUBLIC_DS_API_TOKEN` de la configuration du GPP. Contactez l'administrateur technique pour la mise en place.

## Sécurité

- Le token donne accès en **lecture** aux dossiers de la démarche publique via l'API GraphQL.
- Il doit être conservé de manière sécurisée et ne pas être partagé.
- En cas de compromission, générez un nouveau token sur la plateforme publique et mettez à jour la configuration du GPP.
