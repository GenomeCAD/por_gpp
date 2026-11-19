# GPP + Démarches Simplifiées test environment

This environment runs GPP next to a local Démarches Simplifiées (DS) instance that stands in for the public platform, demarche.numerique.gouv.fr. GPP reads the dossiers submitted on DS through DS's GraphQL API, as it does in production, so the link between a GPP démarche and a public démarche, and the synchronisation of dossiers, can be tested without an account on the public platform.

It is a test setup only: plain HTTP, locally generated secrets, no email.

## What you need

- Docker Engine with the Compose v2 plugin (`docker compose`).
- Ports 3002 (GPP) and 3003 (DS) free on the host.
- About 4 GB of disk for the two images.
- Internet access during the build, for the base images, the gems and the JavaScript packages.

The first build of the two images takes ten to twenty minutes. On first boot, each instance then needs about a minute to load its schema and seed its test account.

## Layout

The two repositories are cloned side by side. Every command below runs from the directory that contains them.

```
workdir/
├── por_gpp/                  GPP (this repository)
│   ├── Dockerfile, docker-compose.yml, bin/docker-entrypoint.sh
│   ├── docker/public-ds/     Docker files for the DS instance
│   └── docker/scripts/       import of sample démarches, for either instance
└── demarches-simplifiees/    upstream DS, with docker/public-ds/ copied in
```

Each instance is a separate Compose project with its own PostgreSQL, Redis, web server (`app`) and delayed_job worker (`worker`). GPP reaches DS through the host, at `http://host.docker.internal:3003`.

## Step 1: Get the code

```bash
git clone https://github.com/GenomeCAD/por_gpp.git
git clone https://github.com/demarche-numerique/demarche.numerique.gouv.fr.git demarches-simplifiees
git -C demarches-simplifiees checkout 2a34f8c7b1303eb73805a7d44c2242e7e33e1e18
cp -r por_gpp/docker/public-ds/. demarches-simplifiees/
```

DS has no Docker setup of its own. The copy adds `Dockerfile`, `docker-compose.yml`, `.dockerignore`, `bin/docker-entrypoint.sh` and `config/image_magick_policy.xml`, none of which exists in DS.

The checkout is upstream commit 2a34f8c7b (9 January 2026), the commit GPP was forked from. The DS Dockerfile patches two DS files at build time so that plain HTTP works (`force_ssl` and the session cookie); with a newer DS commit, check that both patches still apply.

## Step 2: Configure GPP

```bash
cp por_gpp/config/env.example por_gpp/.env
```

In `por_gpp/.env`, set these values, adding the lines that are missing:

```bash
PORT="3002"
APP_HOST="localhost:3002"
FORCE_SSL="false"
SECRET_KEY_BASE="<output of: openssl rand -hex 64>"
INVISIBLE_CAPTCHA_SECRET="<output of: openssl rand -hex 16>"
AR_ENCRYPTION_PRIMARY_KEY="<output of: openssl rand -hex 16>"
AR_ENCRYPTION_KEY_DERIVATION_SALT="<output of: openssl rand -hex 16>"
DB_PASSWORD="<any password>"
```

`PORT` is the host port Compose publishes the web server on. The other values from `env.example` can stay as they are. Leave `PUBLIC_DS_API_URL` and `PUBLIC_DS_API_TOKEN` out for now: step 7 adds them.

## Step 3: Configure DS

```bash
cp demarches-simplifiees/config/env.example demarches-simplifiees/.env
```

In `demarches-simplifiees/.env`, set the same values, with port 3003 and new secrets:

```bash
PORT="3003"
APP_HOST="localhost:3003"
FORCE_SSL="false"
SECRET_KEY_BASE="<output of: openssl rand -hex 64>"
INVISIBLE_CAPTCHA_SECRET="<output of: openssl rand -hex 16>"
AR_ENCRYPTION_PRIMARY_KEY="<output of: openssl rand -hex 16>"
AR_ENCRYPTION_KEY_DERIVATION_SALT="<output of: openssl rand -hex 16>"
DB_PASSWORD="<any password>"
```

## Step 4: Build and start both instances

```bash
(cd por_gpp && docker compose up --build -d)
(cd demarches-simplifiees && docker compose up --build -d)
```

The first `up` on new volumes can stop with `failed to mkdir .../app-tmp/_data/cache: file exists`: the `app` and `worker` containers both fill the shared `app-tmp` volume at the same moment. Run the same command again; the volume is filled by then.

On first boot, each web container loads the database schema, seeds the test account and runs the migrations. The DS one also compiles its stylesheets and images. To follow it:

```bash
(cd demarches-simplifiees && docker compose logs -f app)
```

An instance is ready when its log shows `Listening on http://0.0.0.0:3000`. GPP then answers on http://localhost:3002 and DS on http://localhost:3003.

## Step 5: Let the DS test account log in

DS asks an instructeur for a code sent by email when they log in from a new browser, and this environment sends no email. Turn the check off for the DS test account (GPP's seed already does it on the GPP side):

```bash
(cd demarches-simplifiees && docker compose exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"') <<'SQL'
UPDATE instructeurs SET bypass_email_login_token = true
WHERE id = (SELECT i.id FROM instructeurs i
            JOIN users u ON u.id = i.user_id
            WHERE u.email = 'test@exemple.fr');
SQL
```

## Step 6: Publish a démarche on DS and create an API token

**The démarche.** The import script creates the GIP-CAD's application form for the Comité Scientifique et Éthique (CSE), described in `por_gpp/docker/scripts/cse_procedures_ds.json`, for the test account, and publishes it:

```bash
por_gpp/docker/scripts/import_procedures.sh demarches-simplifiees por_gpp/docker/scripts/cse_procedures_ds.json
```

It prints the démarche's number and its link, `/commencer/depot-candidature-cse`. DS refuses to publish a démarche without a service, so the script also creates a "Service de test" and attaches it. Running it again skips the démarches that already exist. Without a JSON file, the script imports `sample_procedures.json`, two generic démarches; to import your own, pass another JSON file as second argument.

To do the same by hand, log into DS at http://localhost:3003 with the test account (see [Credentials](#credentials)), then:

1. **Create a démarche.** "Créer une nouvelle démarche", then add at least one field to its form.
2. **Give it a service.** On the démarche page, click "Publier", then the "un service" link, then "Nouveau service". Any valid SIRET is accepted, for example `13002526500013`: with no API Entreprise token, nothing is looked up. The contact fields can hold placeholder values. Click "Enregistrer", then "Affecter".
3. **Publish it.** Click "Publier" again, choose the end of the démarche's link, enter any URL as the page where the link is shared, and click "Publier". The démarche number is the number in the démarche's address, `/admin/procedures/<number>`.

**The API token.** Log into DS at http://localhost:3003, open "Mon profil", and in the card "Jetons d'identification de l'API (token)" click "Créer un nouveau jeton". Name it `GPP`, choose "toutes mes démarches" and "de lire uniquement", then "Mon jeton peut être utilisé depuis n'importe quelle adresse IP dans le monde" and a lifetime. Copy the token from the "Votre jeton est prêt" page: DS shows it only once.

The "Jetons API" card in the démarche's settings is for API Entreprise and API Particulier tokens, not for this one.

## Step 7: Link GPP to DS

Add these two lines to `por_gpp/.env`:

```bash
PUBLIC_DS_API_URL="http://host.docker.internal:3003"
PUBLIC_DS_API_TOKEN="<token from step 6>"
```

Restart GPP so that it picks them up (no rebuild needed):

```bash
(cd por_gpp && docker compose up -d)
```

Do this before linking any démarche in GPP. GPP stores the public instance's address in each link when the link is created. Without `PUBLIC_DS_API_URL` in `.env`, Compose passes the variable empty and "Lier" fails with "Erreur lors de la liaison".

## Step 8: Check the link end to end

1. **Submit a dossier on DS**, on the démarche published in step 6, at http://localhost:3003/commencer/depot-candidature-cse (or your own démarche's link). The test account can act as the usager.
2. **Link a GPP démarche.** The same script creates the GPP démarche that reviews these applications, with the seven Oui/Non criteria of the checklist: `por_gpp/docker/scripts/import_procedures.sh por_gpp por_gpp/docker/scripts/cse_procedures_gpp.json`. Log into GPP at http://localhost:3002, open this démarche, enter the DS démarche number in "N° démarche" and click "Lier".
3. **Synchronise.** Open the GPP démarche's dossier list, `http://localhost:3002/procedures/<GPP démarche number>/tous`, and click "Synchroniser". The DS dossier appears, "en instruction".

The README's "Workflow complet" section describes this flow in more detail.

## Credentials

| Instance | Login page                          | Email           | Password                              |
|----------|-------------------------------------|-----------------|---------------------------------------|
| GPP      | http://localhost:3002/pro_connect   | test@exemple.fr | this is a very complicated password ! |
| DS       | http://localhost:3003/users/sign_in | test@exemple.fr | this is a very complicated password ! |

Both accounts come from the instances' `db/seeds.rb`. On GPP, the password form is on the same page as the ProConnect button.

## Everyday commands

Run them in `por_gpp/` or `demarches-simplifiees/`:

- `docker compose stop`, then `docker compose up -d`: stop the instance and start it again, data kept.
- `docker compose up --build -d`: rebuild the image after a code change, then restart.
- `docker compose logs -f app worker`: follow the web server and the worker.
- `docker compose down -v`: delete the instance and its data. The next `up` starts from a new database, seeded again, so steps 5 to 8 must be redone.

## Known limitations

- **No email is sent.** Email jobs fail in the DS worker log (`stack level too deep`), and so does the API Entreprise lookup of a new service (`Le jeton API Entreprise est vide`). Both are expected and block nothing.
- **GPP's "(voir)" link** points to `http://host.docker.internal:3003/...`, which a browser on the host usually cannot open. Use the same path on http://localhost:3003 instead.
- **No PDF attestations.** The Weasyprint service is commented out in both Compose files.
- **The API token expires** at the end of the lifetime chosen in step 6. Create a new one and repeat step 7.
- **Tests only.** When the `procedures` table is missing, the web container's entrypoint drops every table in the database before loading the schema. Do not reuse these Compose files or entrypoints against a database that matters.
