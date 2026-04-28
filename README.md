# hubee-claude-plugin

Plugin Claude Code partagé pour les projets HubEE.

## Installation

```bash
claude plugin marketplace add dinum-HubEE/hubee-claude-plugin
claude plugin install hubee-claude-plugin@hubee-claude-plugin
```

Pour les devs HubEE qui utilisent [`hubee-agent-vm-config`](https://gitlab.hubee.numerique.gouv.fr/hubee/hubee-agent-vm-config), c'est automatique au `agent-vm setup`.

## Mise à jour

Mécanisme valable pour les 4 plugins HubEE (`hubee-claude-plugin`, `superpowers@claude-plugins-official`, `dsfr-skill@dsfr-skill`, `claude-hud@claude-hud`). Deux moyens de récupérer une nouvelle version :

**1. En session (le plus rapide)** — depuis Claude dans la VM :

```bash
claude plugin marketplace update                        # rafraîchit tous les marketplaces
claude plugin update hubee-claude-plugin@hubee-claude-plugin
/exit
```

Puis relancer `agent-vm --git-ro claude`. La 1ʳᵉ commande est obligatoire (sans elle la 2ᵉ ne voit pas les nouveaux commits). Le `/exit` est obligatoire — les skills ne se rechargent pas à chaud. Cette mise à jour est **locale à la VM courante** et perdue si tu fais `agent-vm rm` ensuite.

Pour mettre à jour **tous** les plugins en un coup :

```bash
claude plugin marketplace update
claude plugin update hubee-claude-plugin@hubee-claude-plugin
claude plugin update superpowers@claude-plugins-official
claude plugin update dsfr-skill@dsfr-skill
claude plugin update claude-hud@claude-hud
/exit
```

**2. Re-baker le template Lima (persistant)** :

```bash
cd ~/.agent-vm && git pull && agent-vm setup
```

5-10 min, à faire 1× par mois ou si la config agent-vm partagée a changé. Toutes les VMs créées ensuite auront la dernière version baked-in. **C'est le seul moyen de propager durablement une mise à jour à toutes tes VMs**.

> ⚠️ `agent-vm rm` puis relance ne met **pas** à jour les plugins — la VM est recréée depuis le template Lima local (celui du dernier `agent-vm setup`). Utile pour repartir sur une VM propre, mais reprend la version des plugins figée à la bake. Pour mettre à jour, c'est option 1 ou option 2.

## Activation côté projet

Dans `<projet>/.claude/settings.json` :

```json
{
  "enabledPlugins": {
    "hubee-claude-plugin@hubee-claude-plugin": true,
    "superpowers@claude-plugins-official": true,
    "dsfr-skill@dsfr-skill": true
  }
}
```

`dsfr-skill` est utile uniquement si le projet a une UI Rails. Skip sinon (projet Java backend pur, lib, etc.).

## Skills

| Skill | Quand |
|---|---|
| `api-client` | Consommer l'API HubeeV1 ou un service externe (HTTP client) |
| `architecture` | Décisions de design Rails (database schema, service boundaries) |
| `authentication` | Keycloak OIDC (login, logout, sessions, tokens) |
| `build-fix` | Erreurs CI / build / tests Rails (override `superpowers:systematic-debugging`) |
| `commit` | Préparer un commit (Conventional Commits FR + bin/ci + clipboard handoff) |
| `e2e` | Tests system specs (Capybara/Selenium) + parcours RGAA |
| `execute` | Exécuter un plan step-by-step (override `superpowers:executing-plans`) |
| `explore-rails` | Naviguer un projet Rails route → controller → service → model → view |
| `finishing-branch` | Finaliser une branche, préparer la MR GitLab (override `superpowers:finishing-a-development-branch`) |
| `gitlab` | Lire issues/MR/board/fichiers de l'instance HubEE GitLab via `glab` |
| `hubee-recap` | Résumé mensuel des MR/PR mergées sur HubEE (GitLab interne + GitHub publics), avec « Évolutions notables » par thème |
| `hotwire` | Turbo Frames/Streams, Stimulus controllers |
| `plan` | Rédiger un plan d'implémentation (override `superpowers:writing-plans`) |
| `rails-patterns` | Models, controllers, services, queries Rails |
| `review` | Checklist review HubEE avant push/MR (Rails + RSpec + DSFR + RGAA + Keycloak) |
| `tdd-workflow` | TDD RSpec/FactoryBot/SimpleCov 80% (override `superpowers:test-driven-development`) |

## Rules, hooks, agents

- **Rules** (toujours appliquées) : `principles` (YAGNI > KISS > DRY > SOLID + Rule of Three), `git-workflow`, `security`, `agent-delegation`, `code-style`, `testing`, `performance`, `frontend` (DSFR + RGAA)
- **Hooks** : `pre-bash` (bloque git destructifs), `pre-edit-secrets` (bloque édition `.env`/`master.key`), `pre-edit-rspec-hint`, `post-edit-standardrb`, `on-stop`, `on-notification`
- **Agents** : `explore` (navigation codebase), `security` (vulnérabilités, OWASP)

## Conventions

- Skills : nom anglais, contenu en français
- Override de superpowers par référence (pas de fork — quand superpowers évolue, on en hérite)
- Pas de commande slash (skills-first, déclenchement par description)
- TDD obligatoire sur le code Rails
