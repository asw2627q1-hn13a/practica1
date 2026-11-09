## Requisits

- Ruby (versió indicada a `.ruby-version` / `Dockerfile`)
- Rails 8.1
- Docker Desktop (per a la base de dades local) **o** PostgreSQL 14+ instal·lat
- Git

## Executar l'aplicació en local

Cada membre treballa amb **la seva pròpia base de dades PostgreSQL local**. No es fa servir
la base de dades de Render en desenvolupament: és la de producció (la demo) i no s'hi ha de tocar.

### 1. Clonar el repositori i instal·lar les gems

```bash
git clone https://github.com/asw2627q1-hn13a/practica1
cd practica1
bundle install
```

### 2. Aixecar PostgreSQL

**Amb Docker (recomanat, funciona igual a Windows, macOS i Linux):**

```bash
docker run -d --name hn-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16
```

Les properes vegades només cal `docker start hn-postgres`.

**Sense Docker:**

- Windows: instal·lador oficial de PostgreSQL (recorda el password de l'usuari `postgres`).
- Ubuntu/Debian: `sudo apt install postgresql libpq-dev` i
  `sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"`
- macOS: `brew install postgresql`

### 3. Connexió a la base de dades

Per defecte l'app es connecta com a `postgres` / `postgres` a `localhost`, que és
el que obtens si has aixecat PostgreSQL amb l'ordre Docker del pas anterior.
**En aquest cas no cal fer res i pots passar al pas 4.**

Si el teu PostgreSQL té un altre usuari, password o host, defineix-ho com a
variables d'entorn abans d'executar les ordres de Rails:

| Variable      | Valor per defecte |
|---------------|-------------------|
| `DB_USERNAME` | `postgres`        |
| `DB_PASSWORD` | `postgres`        |
| `DB_HOST`     | `localhost`       |

Exemple (només per a la terminal oberta):

```powershell
# PowerShell (Windows)
$env:DB_PASSWORD = "el_meu_password"
```

```bash
# Linux / macOS / WSL
export DB_PASSWORD=el_meu_password
```

### 4. Crear la base de dades i carregar dades d'exemple

```bash
bin/rails db:create db:migrate db:seed
```

```Windows
ruby bin/rails db:create db:migrate db:seed
```

Això només afecta la teva base de dades local. Per tornar a començar de zero:
`bin/rails db:reset`.

### 5. Arrencar el servidor

```bash
bin/rails server
```

Obre http://localhost:3000.

> A Windows natiu, posa `ruby` davant de cada ordre: `ruby bin/rails server`.

## Executar els tests

Els tests fan servir **una base de dades pròpia**, `hacker_news_test`, diferent de la de
desenvolupament (`hacker_news_development`). Quan algú afegeix una migració i tu fas
`db:migrate`, només s'actualitza la de desenvolupament; la de test es queda enrere.

### Primera vegada i després de cada `git pull` amb migracions noves

```bash
bin/rails db:test:prepare
```

```Windows
ruby bin/rails db:test:prepare
```

Això crea la base de dades de test (si no existeix) i hi carrega l'esquema actual de
`db/schema.rb`. No toca la base de dades de desenvolupament ni les seves dades.

### Executar-los

```bash
bin/rails test                                                # tots els tests
bin/rails test test/controllers/users_controller_test.rb      # un sol fitxer
bin/rails test test/controllers/users_controller_test.rb:12   # un sol test (línia)
```

> A Windows natiu, posa `ruby` davant de cada ordre: `ruby bin/rails test`.

Els tests carreguen les dades de `test/fixtures/*.yml` (usuaris `alice` i `bob`, etc.),
no les de `db/seeds.rb`.

### Problemes habituals

- **`connection refused` a `localhost:5432`**: PostgreSQL no està en marxa (`docker start hn-postgres`).
- **`password authentication failed`**: ajusta `DB_USERNAME` i `DB_PASSWORD`.
- **El port 5432 ja està ocupat**: tens un altre PostgreSQL local; para'l o canvia el port del contenidor (`-p 5433:5432`) i defineix `DB_PORT`.
- **`Migrations are pending` en executar els tests**, tot i haver fet `db:migrate`: la base de
  dades de test és diferent de la de desenvolupament i està desactualitzada. Executa
  `bin/rails db:test:prepare` i torna a provar.
- **`database "hacker_news_test" does not exist`**: el mateix, `bin/rails db:test:prepare`
  la crea.