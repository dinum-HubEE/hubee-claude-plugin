# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

Ajouter à `~/.claude/settings.json` (user-scope) ou `<projet>/.claude/settings.json` (projet) :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@gitlab.hubee.numerique.gouv.fr/hubee/hubee-claude-plugin": true
  }
}
```

L'installation est automatisée pour les devs HubEE via le repo [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config) (`setup.sh`).

> Plugin interne : pas de versionning ni de tag — la branche `main` est la version courante.

## Contenu

- **`skills/`** — déclenchement automatique par contexte (skills-first, zéro commande slash)
- **`rules/`** — règles toujours appliquées (principes, code style, sécurité, tests, etc.)
- **`hooks/`** — automatisations (pre-bash, pre-edit, post-edit, on-stop…)
- **`agents/`** — agents spécialisés (`explore`, `security`)

Pour la liste exhaustive et le rationale, voir le projet portail admin V1 :
`.notes/chore-claude-setup/doctrine.md` (§4 Plugin HubEE).

## Conventions

- **Skills** : nom anglais (`commit`, `plan`, `review`), contenu rédigé en français pour le métier
- **Override de superpowers** : les skills `plan`, `execute`, `finishing-branch` étendent `superpowers:writing-plans` / `executing-plans` / `finishing-a-development-branch` par référence (pas de fork — cf. doctrine §4.4)
- **Pas de commande slash** : déclenchement uniquement par description de la skill
- **TDD obligatoire** sur le code Rails, conventions RSpec/FactoryBot/SimpleCov 80%

## Statut

Squelette initial. Migration des skills/rules/hooks/agents depuis le portail admin V1 en cours (cf. plan `chore/claude-setup` du portail admin).
