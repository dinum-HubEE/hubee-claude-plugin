---
name: proconnect
description: "Authentification ProConnect (OIDC) du portail V2 : niveaux acr et MFA, vérification des jetons, state/nonce, pièges vérifiés du fournisseur. À utiliser pour tout code touchant lib/portail/pro_connect/, la session portail ou les niveaux d'authentification. Pour le Keycloak du portail admin, voir la skill authentication."
globs:
  - "lib/portail/pro_connect/**"
  - "app/models/portail/authentication_levels.rb"
  - "app/models/portail/second_factor.rb"
  - "app/controllers/portail/sessions_controller.rb"
  - "config/initializers/pro_connect.rb"
---

# ProConnect (OIDC) — portail V2

Savoirs **vérifiés expérimentalement** sur l'environnement d'intégration ProConnect (fournisseurs d'identité de test compris). En cas de doute, refaire l'essai plutôt que supposer un comportement standard OIDC : ProConnect s'en écarte sur plusieurs points listés ici.

## Exiger la MFA : `claims` ET `acr_values`, jamais l'un sans l'autre

Pour obtenir un niveau élevé, la requête d'autorisation doit porter **à la fois** :

- `claims` avec `id_token.acr` en `essential: true` et les valeurs exigées — c'est ce qui fait répondre ProConnect par une **erreur** plutôt que par un niveau plus faible ;
- `acr_values` avec les mêmes valeurs — **sans `acr_values`, ProConnect n'émet aucun `acr` dans le jeton**.

L'un sans l'autre est silencieusement ignoré. Les deux doivent demander la même chose : un plancher dans `acr_values` contredirait l'exigence des `claims`.

## Le userinfo arrive en JWT signé, pas en JSON

ProConnect renvoie le userinfo en **JWT signé** là où `userinfo!` de la gem `openid_connect` attend du JSON. Le décoder soi-même, **signature vérifiée** (JWKS, algorithme imposé côté client, jamais lu dans le jeton). Ce format dépend de l'enregistrement du client ProConnect — **à vérifier par client**, ne pas le supposer identique d'un enregistrement à l'autre.

## `amr` n'est pas fiable — l'`acr` certifié est la source de vérité

Vérifié : le FI ANCT renvoie un `amr` **vide** même à `eidas1-mfa`. Règle :

- le **niveau `acr` du jeton vérifié** est la seule source de vérité du niveau d'authentification ;
- `amr` ne s'utilise qu'en **tolérance additive** : un `amr` contenant `"mfa"` peut *satisfaire* une exigence de second facteur (FI qui impose sa propre MFA sans être qualifié pour l'attester en niveau — l'`acr` reste `eidas1`), mais jamais l'inverse : un `amr` vide ne dégrade rien.

## Élévation (step-up) : suggérer, ne jamais faire confiance

- `login_hint` (adresse) et `siret_hint` (organisation) pré-remplissent le parcours d'élévation — **suggestions seulement** : c'est l'`acr` du jeton au retour qui fait foi.
- `prompt=login` est **ignoré par ProConnect** (vérifié) : pour forcer une ré-authentification, le RP-initiated logout (`end_session_endpoint` + `id_token_hint`) reste nécessaire.
- Aucun paramètre ne saute l'écran de ré-identification : `login_hint` pré-remplit seulement, `id_token_hint` n'est pas accepté sur l'autorisation, `prompt` est tout ou rien.

## `state` et `nonce`

- `state` : comparaison **à temps constant** (`ActiveSupport::SecurityUtils.secure_compare`) et **usage unique** — le consommer (`session.delete`) au premier retour, un `state` ne vaut qu'un aller-retour.
- `nonce` : vérifié **après** la signature seulement (un claim non signé ne prouve rien), présence exigée des deux côtés — un nonce attendu absent ne doit jamais faire passer la comparaison.

## Vérification de l'id_token

Un seul endroit vérifie l'id_token (`TokenVerifier`). La gem porte la signature et le jeu de clés (JWKS avec rafraîchissement sur rotation de `kid`) ; les contrôles de contenu (`sub`, `iss`, `aud`, `exp` avec marge d'horloge, `nonce`) restent chez nous. L'algorithme accepté est **imposé** (`RS256`), jamais lu dans l'en-tête du jeton : un HS256 signé avec la clé publique passerait sinon.

## Frontière domaine / protocole

- **Domaine** (`app/models/<namespace>/`) : niveaux d'authentification, règle de second facteur — le vocabulaire métier.
- **Protocole** (`lib/<namespace>/pro_connect/`) : client OIDC, vérification de jetons — le dialogue avec le fournisseur.

Sur la gem à utiliser pour le dialogue OIDC lui-même (et pourquoi ce n'est pas du Net::HTTP maison), voir la skill `api-client`.

## Référence d'implémentation

Le dépôt public `datagouv/hubee` porte l'implémentation de référence : `lib/portail/pro_connect/` (client + token_verifier), `app/models/portail/authentication_levels.rb`, `app/models/portail/second_factor.rb`.
