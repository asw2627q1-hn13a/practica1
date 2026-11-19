# Visió general del projecte — Hacker News clone

Clon de Hacker News per a l'assignatura ASW. Aquest document descriu **l'abast**, la
**tecnologia**, **on viu cada part del codi**, les **pantalles** i les **funcionalitats
actuals**. No parla de qui ha fet cada cosa.

---

## 1. Abast

Rèplica funcional de Hacker News amb:

- Publicació de **submissions** de tipus *url* i *ask* (pregunta).
- **Comentaris** en arbre de profunditat il·limitada (reply a reply a reply…).
- **Accions** sobre submissions i comentaris: votar, favorit, amagar, editar, esborrar.
- **Llistats**: portada (news), newest, ask, threads, comments.
- **Usuaris** amb login extern (GitHub), perfil públic amb avatar/banner i llistats
  d'activitat.

Fora d'abast en aquest lliurament: pàgines `past`, `show`, `jobs` i el replegar/desplegar
(`[–]`) de subarbres de comentaris.

---

## 2. Tecnologia

| Capa | Tecnologia |
|---|---|
| Framework | **Ruby on Rails 8.1** (Ruby indicat a `.ruby-version`) |
| Base de dades | **PostgreSQL** (gem `pg`) — patró de BD separada en producció |
| Servidor web | **Puma** |
| Assets | **Propshaft** + **importmap** (sense bundler de JS) |
| Front dinàmic | **Hotwire** (Turbo + Stimulus) |
| Autenticació | **OmniAuth** amb GitHub (`omniauth-github`, `omniauth-rails_csrf_protection`) |
| Imatges | **Active Storage** (disc en local; object storage extern en producció) + `image_processing` |
| Vistes | ERB; respostes JSON amb **Jbuilder** |
| Tests | **Minitest** (fixtures) |
| Desplegament | **Render** (servei web + BD PostgreSQL gestionada separada), blueprint a `render.yaml` |

---

## 3. On viu cada part del codi

### Models — `app/models/`
| Fitxer | Responsabilitat |
|---|---|
| `user.rb` | Usuari (provider/uid de GitHub, username, email, about). Avatar/banner (Active Storage) amb imatges per defecte i validació de pujada. `karma`. Relacions amb submissions, comments, votes, favorites, hides. |
| `submission.rb` | Submission (title, url, text, submission_type, points, comments_count). Validació de format d'URL i scopes d'ordenació (`ranked`, `by_time`, `of_type`). Helpers `owned_by?/voted_by?/favorited_by?/hidden_by?`. |
| `comment.rb` | Comentari (body, points) amb **auto-referència** (parent/replies) per a l'arbre; scopes `chronological`, `by_recent`, `roots`; validació que una resposta pertany a la mateixa submission. |
| `vote.rb` | Vot **polimòrfic** (`votable`: Submission o Comment); únic per usuari+element. |
| `favorite.rb` | Favorit **polimòrfic** (`favoritable`); únic per usuari+element. |
| `hide.rb` | Submission amagada per un usuari; únic per usuari+submission. |

### Controladors — `app/controllers/`
| Fitxer | Responsabilitat |
|---|---|
| `application_controller.rb` | `current_user`, `require_login` (helpers compartits). |
| `sessions_controller.rb` | Login via OAuth GitHub (`create`), `failure`, **logout** (`destroy`). |
| `submissions_controller.rb` | Llistats (index/news, newest, ask), detall (show), crear/editar/esborrar, i accions vote/unvote/favorite/unfavorite/hide/unhide + pàgina `hidden`. |
| `comments_controller.rb` | Crear/reply (new, create), llistats `index` (comments) i `threads`, editar/esborrar, i vote/unvote/favorite/unfavorite de comentaris. |
| `users_controller.rb` | Perfil (show, edit, update) i pestanyes d'activitat (submissions, favorites, upvoted). |

### Vistes — `app/views/`
- `layouts/application.html.erb` → **menú superior HN** i estructura comuna.
- `submissions/` → `index` (llistats), `show` (detall + arbre de comentaris), `new`,
  `edit`, `delete` (confirmació sense JS), `hidden`, i parcials `_item` (fila de llistat),
  `_actions` (vot/favorit/hide/edit/delete), `_comment` (node de l'arbre, recursiu).
- `comments/` → `index` (comments recents), `threads` (els meus comentaris), `new`
  (formulari de reply), `edit`, `delete`, parcial `_listed`.
- `users/` → `show` (perfil), `edit`, pestanyes `submissions`, `favorite_submissions`,
  `favorite_comments`, `upvoted_submissions`, `upvoted_comments` i parcials de navegació.
- `sessions/new.html.erb` → pàgina de login.

### Altres
- `config/routes.rb` → totes les rutes (vegeu §4).
- `db/migrate/` + `db/schema.rb` → esquema (users, submissions, comments, votes, favorites,
  hides + taules d'Active Storage).
- `db/seeds.rb` → dades d'exemple.
- `app/assets/stylesheets/application.css` → estil tipus HN.
- `render.yaml`, `.env.example`, `README.md` → desplegament i execució local.
- `test/` → tests de models, controladors, integració; fixtures a `test/fixtures/`.

---

## 4. Pantalles i en què es diferencien

| Ruta | Pantalla | Què mostra / la diferència |
|---|---|---|
| `/` i `/news` | **News (portada)** | Només submissions de tipus **url**, ordenades per **punts** (relevància). |
| `/newest` | **Newest** | **Totes** les submissions (url i ask), de més **recent** a més antiga. |
| `/ask` | **Ask** | Només submissions de tipus **ask** (preguntes, sense url), per data. |
| `/submit` | **Submit** | Formulari per crear submission (title, url, text). |
| `/submissions/:id` | **Detall de submission** | Dades de la submission + **arbre complet de comentaris** + formulari per comentar. |
| `/submissions/:id/comments/new` | **Reply / comentari** | Formulari per respondre un comentari concret (o comentar). |
| `/submissions/:id/edit` | **Editar submission** | Formulari d'edició (només propietari). |
| `/submissions/:id/delete` | **Confirmar esborrat** | Confirmació **sense JavaScript** abans d'esborrar. |
| `/threads` | **Threads** | Els comentaris **de l'usuari loguejat** amb les respostes rebudes. |
| `/comments` | **Comments** | Els **últims comentaris de tothom**, cada un amb enllaç a la seva submission. |
| `/hidden` | **Hidden** | Les submissions que l'usuari ha **amagat** (amb opció unhide). |
| `/upvoted`, `/upvoted/comments` | **Upvoted** | Submissions i comentaris que l'usuari ha **votat**. |
| `/users/:id` | **Perfil** | Avatar, banner, nom, data d'alta, about + pestanyes d'activitat. |
| `/users/:id/edit` | **Editar perfil** | About, email i pujada/reset d'avatar i banner (propi). |
| `/users/:id/submissions`, `.../favorite_submissions`, `.../favorite_comments` | **Pestanyes del perfil** | Submissions, comentaris i favorits de l'usuari. |
| `/login` | **Login** | Inici de sessió amb GitHub (login = registre el primer cop). |

> Diferència clau entre llistats: **news** = url per punts · **newest** = tot per data ·
> **ask** = ask per data · **threads** = els meus comentaris · **comments** = tots els
> comentaris recents.

---

## 5. Funcionalitats actuals

### Submissions
- Crear submission **url** (es valida el format http/https) o **ask** (sense url).
- **Detecció de duplicats**: si la url ja existeix, mostra la submission existent en lloc de
  duplicar.
- Editar i esborrar (només el propietari; esborrar arrossega els comentaris).
- Domini mostrat al costat del títol.

### Comentaris
- Afegir comentari a una submission.
- **Respondre a qualsevol profunditat** (arbre il·limitat), amb indentació.
- Veure la submission amb el **(sub)arbre complet** de comentaris.
- Editar i esborrar comentaris propis.

### Accions (sobre submissions i comentaris)
- **Vot / unvot** (no al contingut propi; 1 vot per usuari; afecta punts i ordre).
- **Favorit / treure favorit**.
- **Amagar / mostrar** (només submissions; les amagades surten dels llistats d'aquell usuari).

### Usuaris
- **Login/registre** amb GitHub (extern) i **logout**.
- Perfil públic de qualsevol usuari; edició del propi.
- **Avatar i banner**: per defecte en registrar-se, editables (amb validació de tipus/mida).
- Llistats al perfil: submissions, comentaris, favorits, upvoted i hidden (propi).
- **Karma** (suma de punts de les submissions) al menú.

### Navegació i layout
- Menú superior estil HN present a totes les pàgines (news, threads, comments, ask, submit,
  cerca, usuari/karma, logout).

---

## 6. Estat conegut / pendent

- **Cercador (SRC-01)**: la caixa de cerca del menú **encara no té backend** (ruta `/search`
  inexistent). Pendent d'implementar.
- **Normalització d'URL en duplicats**: la comprovació és de coincidència exacta; variants
  amb barra final, majúscules o http/https es consideren diferents.
- **Formulari d'editar submission**: mostra camps interns (points, user, submission_type)
  que no s'haurien d'editar (només hauria de permetre title/url/text).

> Aquests punts estan registrats com a *Issues* al Taiga del projecte.
