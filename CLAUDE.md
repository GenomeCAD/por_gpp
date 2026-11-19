# CLAUDE.md - por_gpp (Gestionnaire des Processus Projets)

Working rules for this repository, for Claude Code and for the developers using it. The upstream project's agent guide is imported below; it describes the Rails application this repository was forked from, and stays accurate for most of the code. Where this file and AGENTS.md disagree, this file wins: it describes the fork.

@AGENTS.md

## What this is

The GPP is the GIP-CAD's fork of démarche numérique (formerly demarches-simplifiees.fr), reworked to instruct the application dossiers submitted on the public platform demarche.numerique.gouv.fr. Applicants never use the GPP: it reads their dossiers from the public platform through its GraphQL API, and GIP-CAD instructors review them with GPP-specific tools (a yes/no checklist with notes and attachments per field, and the CSE meeting calendar). README.md, in French, describes the full workflow.

The fork starts from upstream commit `2a34f8c7b`. Upstream changes have not been merged since, and there is no upstream remote. Merging upstream is a project of its own (the fork removed the applicant-facing pages, about 11 800 lines), not a side task.

## What GPP adds

```
app/models/procedure_mirror.rb            a GPP démarche linked to a public démarche (URL + number, auto-sync frequency)
app/models/linked_dossier.rb              a local dossier linked to a public one (number, URL, state, applicant identity)
app/models/champ_note.rb                  an instructor's note and attachments on a checklist field
app/models/cse_date.rb                    a CSE meeting date configured for a démarche
app/services/public_dossier_sync_service.rb   GraphQL synchronisation from the public platform
app/jobs/sync_dossiers_job.rb             periodic synchronisation of one démarche
config/initializers/auto_sync_scheduler.rb    re-enqueues auto-sync jobs at boot
app/controllers/administrateurs/procedures_controller.rb   link, unlink, sync settings, CSE calendar
app/controllers/instructeurs/procedures_controller.rb      manual synchronisation, dossier table
app/javascript/controllers/champ_note_controller.ts, app/views/instructeurs/champ_notes/
db/migrate/202602*_create_{procedure_mirrors,linked_dossiers,champ_notes,cse_dates}.rb
docker/public-ds/   Docker files for a local DS instance that stands in for the public platform
docker/scripts/     import of sample démarches into either instance
```

## Where AGENTS.md does not apply

- **Jobs run on delayed_job, not Sidekiq.** `Procfile.dev` and the Docker worker run `bin/rake jobs:work`, and the Docker image sets `RAILS_QUEUE_ADAPTER=delayed_job`. `auto_sync_scheduler.rb` looks for pending jobs in the `Delayed::Job` table, so auto-sync depends on that adapter. `production.rb` still defaults to Sidekiq when `RAILS_QUEUE_ADAPTER` is unset: set it explicitly in any deployment.
- **No applicant (usager) pages.** They were removed from the fork. Dossiers are created by the synchronisation, in the "en instruction" state, never by a form submission.
- **Contribution rules.** The upstream rules (French PR titles in the "ETQ ..." form, GPG-signed commits, upstream issue references, Crisp support) are the upstream team's. This repository's conventions are in "Git" below.
- **Tests required.** Upstream requires tests with every change, and the GPP-specific code above has none yet. Any change to it comes with specs (`spec/models/`, `spec/services/`, `spec/jobs/`, `spec/system/` for the instructor screens), and adding specs for the existing GPP code is welcome.

## Running it

- Locally: README.md ("Installation", "Lancement de l'application"). Ruby from `.ruby-version`, Bun, PostgreSQL, Redis. `bin/setup`, then `bin/dev` on http://localhost:3000. The seeded test account is in `db/seeds.rb`.
- With a local public platform: DOCKER-SETUP.md runs GPP and a DS instance side by side under Docker (ports 3002 and 3003) and walks through linking and synchronising, end to end. Its Compose files and entrypoints are for tests only: the entrypoint drops every table when the `procedures` table is missing, so never point them at a database that matters.
- Tests and linters: `bin/rspec <spec file>`, `bin/rake lint`. The full suite is long; run the specs of the area you change, and let CI (`.github/workflows/ci.yml`, on pushes to `main` and pull requests) run the rest.

## Things that are easy to get wrong

- `PUBLIC_DS_API_URL` is read when a démarche is linked and stored in its `ProcedureMirror`; changing the variable later does not move existing links. Without it, a link points to `https://www.demarches-simplifiees.fr`.
- `PUBLIC_DS_API_TOKEN` is read at each synchronisation. Without it, the manual buttons show an alert and the auto-sync job does nothing, silently. It is a read-only GraphQL token created on the public platform's profile page ("Jetons d'identification de l'API (token)"), not on the démarche's "Jetons API" card.
- The public platform refuses to publish a démarche that has no "service".
- Dossiers hold applicants' personal data. Use the seeded and sample data only; never copy real dossiers into fixtures, specs, logs or messages.
- Comments explain a non-obvious why. Do not restate the code; match the density of the surrounding file.

## Documentation

- README.md (French) and DOCKER-SETUP.md (English) describe the GPP, and ARCHITECTURE.md (French) is the architecture proposal: the flows in place, the target evolutions and the decisions expected from the GIP-CAD. The upstream documents (CONTRIBUTING, `doc/`) describe démarche numérique. Update the GPP documents when GPP behaviour changes, including the flows that ARCHITECTURE.md marks as in place.
- Describe the current state only: history belongs in commits.
- Check every number and every UI label you quote against the application.
- Markdown prose is not hard-wrapped: one paragraph, one line. ASCII punctuation only: `-` rather than em or en dashes, `->` rather than arrow characters.

## Git

- The developer runs git and GitHub operations. Do not commit or push unless asked in the session.
- Changes have so far been pushed directly to `main` of `GenomeCAD/por_gpp`, without issues or pull requests. If pull requests are introduced, the review rule below applies to them unchanged.
- Commit messages are one line, lowercase, `<type>/<scope>: <imperative description>`, in English, with no body and no trailers. Examples: `fix/services: treat an empty recherche entreprises result as a failure`, `chore/ci: run ci on pushes to main, pin bun, drop codecov, bors and publiccode.yml`. When a change spans two concerns, propose two commits.

## Reviews: always a fresh agent

Every review of an implementation is done by a separate agent started with a clean context, created anew for each review. This applies to pull requests of every kind, and, since changes here go straight to `main`, to every set of commits before it is pushed, and to each new round after fixes.

- Never review in the session or agent that wrote or changed the code, and never with a forked agent, which inherits the implementer's conversation. In Claude Code, launch the reviewer with the Agent tool and a non-fork agent type (for example `general-purpose`), or start a new session (`/clear`, or a new terminal) before running a review command such as `/code-review`.
- One review, one agent. After fixes, start another fresh agent for the next round instead of resuming the previous reviewer, which carries its own earlier conclusions.
- Brief the reviewer with facts only: the pull request number or the `base..head` range (for unpushed work, `origin/main..HEAD`), what was asked, the README, DOCKER-SETUP or ARCHITECTURE sections it touches, and the commands above. Do not pass on the implementer's summary, reasoning or self-assessment: the reviewer reads the diff and the code itself.
- Ask the reviewer to check the change against what was asked, run the specs of the area and the linters and say what did not run, check that README.md, DOCKER-SETUP.md and ARCHITECTURE.md are still true, and check the rules in this file and in AGENTS.md (accessibility, security). Each finding comes with `file:line` and a concrete failure scenario. The reviewer reports; it does not edit.
- The implementing agent answers every finding, by fixing it or by explaining to the developer why not. No finding is dropped silently. The developer decides and pushes; an agent review does not replace theirs.

Why: an agent that has just written the code shares its assumptions, its reading of the request and its blind spots, and tends to check what it meant to write rather than what is there.
