# Disseny de l'API REST (REST-01)

API REST de **nivell 2 del Richardson Maturity Model**: recursos amb URI pròpia
(nivell 1) i ús correcte dels verbs HTTP i dels codis d'estat (nivell 2). No té
hipermèdia (nivell 3).

Aquest document és el contracte que segueixen les històries API-01 a API-17 i que
documentaran DOC-01 i DOC-02 a `api/api.yaml`. Les rutes estan definides a
`config/routes.rb` (namespace `api/v1`) i fixades pel test
`test/integration/api_v1_routes_test.rb`.

---

## 1. Convencions generals

| Tema | Decisió |
|---|---|
| Prefix | Totes les rutes sota **`/api/v1`**. A l'`api.yaml`, `servers.url` és l'URL de l'aplicació desplegada i els `paths` comencen per `/api/v1/...`. |
| URIs | Noms en plural i minúscules; **mai verbs** (`/submissions/3/votes`, no `/submissions/3/upvote`). Ids numèrics. |
| Format | Peticions i respostes en **JSON** (`Content-Type: application/json`). JSON pla, sense embolcall (`{"title": "..."}`, no `{"submission": {...}}`). Només `PUT /users/{id}/images` usa `multipart/form-data`. |
| Camps de data | ISO 8601 en UTC (`2026-11-20T10:15:00Z`). |
| Autenticació | Capçalera **`X-API-KEY: <api-key>`** a **totes** les peticions, també les GET (API-02). Esquema OpenAPI `apiKey`, `in: header`, `name: X-API-KEY`. |
| Usuari actiu | S'obté **sempre de l'api-key**, mai del cos de la petició (un `user_id` al JSON s'ignora). |
| Actualització | `PUT` amb semàntica parcial: només es modifiquen els camps enviats i només els editables. `points`, `user`, `submission_type`, `id` i dates mai es poden modificar. (Rails també accepta `PATCH` com a àlies, però no es documenta.) |
| Llistats | Sempre un array JSON; si no hi ha resultats, `[]` amb `200`. Sense paginació (la web tampoc en té). |
| CORS | Habilitat només per a `https://editor.swagger.io` i només sota `/api/*` (INF-05, `config/initializers/cors.rb` amb la gem `rack-cors`): mètodes `GET, POST, PUT, DELETE, OPTIONS` i capçaleres `Accept`, `Content-Type` i `X-API-KEY`. El preflight `OPTIONS` el respon el middleware sense api-key. Per provar l'editor contra `localhost`, Chrome demana permís d'accés a la xarxa local (*Local Network Access*); contra l'URL desplegada no cal. |
| Rutes inexistents | Tot el prefix `/api` és reservat a l'API: qualsevol ruta que no existeixi (`/api/v1/foo`, `/api/v2/...`, `/api/foo`) respon **404 en JSON**. Un **verb no definit sobre una ruta existent** (p. ex. `DELETE /api/v1/submissions`) també respon **404**, no 405: Rails no calcula la capçalera `Allow` i no val la pena complicar-ho. Fora de `/api`, les pàgines d'error de la web continuen sent HTML. |
| Fora de l'API | Login, registre i logout (l'enunciat els exclou). No hi ha `POST /users` ni `DELETE /users/{id}`. |

### Codis d'estat

| Codi | Quan s'usa |
|---|---|
| **200 OK** | GET, PUT i accions que retornen un recurs o dades (p. ex. els `points` en desvotar). |
| **201 Created** | POST que crea un recurs. |
| **204 No Content** | DELETE correcte sense cos. |
| **400 Bad Request** | Cos que no és JSON vàlid, falta un paràmetre obligatori o un paràmetre de consulta té un valor no permès (p. ex. `list=foo`). |
| **401 Unauthorized** | Falta l'api-key o no correspon a cap usuari. |
| **403 Forbidden** | L'api-key és vàlida però l'usuari no pot fer l'acció: contingut d'un altre usuari, votar el contingut propi, llistats privats d'un altre usuari. |
| **404 Not Found** | El recurs (o el recurs pare) no existeix. També una ruta inexistent sota `/api/v1`. |
| **409 Conflict** | L'acció xoca amb l'estat actual: url de submission duplicada, vot/favorit/hidden ja existent. |
| **422 Unprocessable Entity** | El JSON és correcte però no passa les validacions (títol buit, url amb format invàlid, text buit, fitxer que no és una imatge...). |
| **500 Internal Server Error** | Error inesperat del servidor. Mateix format JSON, amb un missatge genèric (el detall només queda al log). |

**Ordre de comprovació:** 401 → 404 → 403 → 400/422/409. Una petició sense api-key
sempre és 401, encara que el recurs no existeixi.

---

## 2. Recursos i endpoints

Les URIs són relatives a `/api/v1`. `operationId` és el nom que han de tenir a l'`api.yaml`
(`tags` = recurs). Els errors 400 i 401 poden sortir a qualsevol endpoint i no es repeteixen.

### 2.1 Submissions

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| GET | `/submissions` | `listSubmissions` | API-03 | 200 | — |
| POST | `/submissions` | `createSubmission` | API-04 | 201 | 409, 422 |
| GET | `/submissions/{id}` | `getSubmission` | API-05 | 200 | 404 |
| PUT | `/submissions/{id}` | `updateSubmission` | API-06 | 200 | 403, 404, 422 |
| DELETE | `/submissions/{id}` | `deleteSubmission` | API-06 | 204 | 403, 404 |

**`GET /submissions`** — query params:

| Paràmetre | Valors | Per defecte | Efecte |
|---|---|---|---|
| `list` | `news`, `newest`, `ask` | `news` | `news` = tipus `url` ordenades per `points` (més a menys); `newest` = totes per data (més recent primer); `ask` = només tipus `ask` per data. |
| `q` | text | — | Cerca per paraula del títol, sense distingir majúscules. **Sense `list`** cerca a totes les submissions ordenades per `points` (com `/search` a la web); amb `list`, filtra aquell llistat. |

Totes les submissions que l'usuari de l'api-key ha amagat queden excloses dels llistats.

**`POST /submissions`** — cos `{ "title": "...", "url": "...", "text": "..." }` (`title` obligatori).
Amb `url` vàlida és tipus `url`; sense `url`, tipus `ask`. Si la `url` ja existeix: **409** amb
`details.existing_submission_id` (no es crea res; no s'envia `Location`, que a HTTP és per a 201/3xx).

**`GET /submissions/{id}`** — la submission amb l'**arbre complet de comments** niat a `comments`.

### 2.2 Comments

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| GET | `/comments` | `listComments` | API-10 | 200 | — |
| POST | `/submissions/{submissionId}/comments` | `addComment` | API-07 | 201 | 404, 422 |
| POST | `/comments/{commentId}/replies` | `replyToComment` | API-07 | 201 | 404, 422 |
| GET | `/comments/{id}` | `getComment` | API-08 | 200 | 404 |
| PUT | `/comments/{id}` | `updateComment` | API-09 | 200 | 403, 404, 422 |
| DELETE | `/comments/{id}` | `deleteComment` | API-09 | 204 | 403, 404 |

- Cos de creació i edició: `{ "body": "..." }`. Una resposta (`replies`) hereta la submission del comment pare.
- `GET /comments` retorna els comments de tots els usuaris, del més recent al més antic, **plans** (sense arbre).
- `GET /comments/{id}` retorna el comment amb el seu **subarbre** a `replies`.
- Esborrar un comment esborra les seves respostes (igual que la web).

### 2.3 Votes

El vot és un recurs que penja de l'element votat i del qual n'hi ha com a màxim un per usuari.
No cal id de vot: l'element i l'api-key el identifiquen.

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| POST | `/submissions/{submissionId}/votes` | `voteSubmission` | API-11 | 201 | 403 (contingut propi), 404, 409 (ja votat) |
| DELETE | `/submissions/{submissionId}/votes` | `unvoteSubmission` | API-11 | 200 | 404 (no existeix o no l'havies votat) |
| POST | `/comments/{commentId}/votes` | `voteComment` | API-11 | 201 | 403, 404, 409 |
| DELETE | `/comments/{commentId}/votes` | `unvoteComment` | API-11 | 200 | 404 |

Les dues respostes (`201` i `200`) retornen els punts actualitzats: `{ "points": 12 }`.
> **Atenció, excepció intencionada:** `DELETE .../votes` retorna **200 amb `points`** (API-11 demana
> retornar els punts actualitzats), mentre que `DELETE .../favorites` i `DELETE .../hidden` retornen
> **204 sense cos**.

### 2.4 Favorites

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| POST | `/submissions/{submissionId}/favorites` | `favoriteSubmission` | API-12 | 201 | 404, 409 (ja és favorit) |
| DELETE | `/submissions/{submissionId}/favorites` | `unfavoriteSubmission` | API-12 | 204 | 404 (no existeix o no era favorit) |
| POST | `/comments/{commentId}/favorites` | `favoriteComment` | API-12 | 201 | 404, 409 |
| DELETE | `/comments/{commentId}/favorites` | `unfavoriteComment` | API-12 | 204 | 404 |

El POST retorna `{ "favorited": true }`. El DELETE retorna 204 (a diferència de `.../votes`).

### 2.5 Hidden (només submissions)

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| POST | `/submissions/{submissionId}/hidden` | `hideSubmission` | API-13 | 201 | 404, 409 (ja amagada) |
| DELETE | `/submissions/{submissionId}/hidden` | `unhideSubmission` | API-13 | 204 | 404 (no existeix o no estava amagada) |

El POST retorna `{ "hidden": true }`; el DELETE retorna 204 (a diferència de `.../votes`). Amagar només afecta els llistats de l'usuari de l'api-key.

### 2.6 Users

| Mètode | URI | operationId | Història | Èxit | Altres errors |
|---|---|---|---|---|---|
| GET | `/users/{id}` | `getUser` | API-14 | 200 | 404 |
| PUT | `/users/{id}` | `updateUser` | API-15 | 200 | 403, 404, 422 |
| PUT | `/users/{id}/images` | `uploadUserImages` | API-16 | 200 | 403, 404, 422 |
| DELETE | `/users/{id}/images/{kind}` | `resetUserImage` | API-16 | 200 | 403, 404 |
| GET | `/users/{id}/submissions` | `listUserSubmissions` | API-14 | 200 | 404 |
| GET | `/users/{id}/comments` | `listUserComments` | API-14 | 200 | 404 |
| GET | `/users/{id}/threads` | `listUserThreads` | API-10 | 200 | 404 |
| GET | `/users/{id}/favorites/submissions` | `listUserFavoriteSubmissions` | API-14 | 200 | 404 |
| GET | `/users/{id}/favorites/comments` | `listUserFavoriteComments` | API-14 | 200 | 404 |
| GET | `/users/{id}/upvoted/submissions` | `listUserUpvotedSubmissions` | API-17 | 200 | 403, 404 |
| GET | `/users/{id}/upvoted/comments` | `listUserUpvotedComments` | API-17 | 200 | 403, 404 |
| GET | `/users/{id}/hidden` | `listUserHidden` | API-17 | 200 | 403, 404 |

- `PUT /users/{id}` — cos `{ "about": "...", "email": "..." }`.
- `PUT /users/{id}/images` — `multipart/form-data` amb les parts `avatar` i/o `banner` (fitxers). Retorna el perfil amb les noves `avatar_url`/`banner_url`. Si el fitxer no és PNG, JPEG, GIF o WebP, o pesa més de 5 MB: 422.
- `DELETE /users/{id}/images/{kind}` — `kind` = `avatar` o `banner`; torna a la imatge per defecte (com a la web). Un altre valor de `kind`: 404.
- `threads`: els comments de l'usuari amb les respostes rebudes (array de comments amb `replies`). És públic, com `/threads?id=` a la web; l'usuari de l'api-key és un cas particular.
- `upvoted/*` i `hidden` són **privats**: només si `{id}` és l'usuari de l'api-key; si no, 403.
- Què retornen: `hidden` → array de **Submission** amagades per l'usuari; `upvoted/submissions` → array de **Submission** votades; `upvoted/comments` → array de **Comment** (plans, amb `submission`) votats. Ordenats per data de l'acció, del més recent al més antic.
- Tots els llistats d'usuari van del més recent al més antic (`favorites/*` i `upvoted/*`: per data de l'acció).

---

## 3. Representacions JSON

### Submission
```json
{
  "id": 7,
  "title": "Show HN: My project",
  "url": "https://github.com/foo/bar",
  "domain": "github.com",
  "text": null,
  "submission_type": "url",
  "points": 12,
  "comments_count": 3,
  "user": { "id": 2, "username": "alice" },
  "created_at": "2026-11-20T10:15:00Z",
  "updated_at": "2026-11-20T10:15:00Z"
}
```
`GET /submissions/{id}` afegeix `"comments": [ <Comment amb replies>, ... ]` (només els comments directes; la resta, niats).

### Comment
```json
{
  "id": 21,
  "body": "Great post",
  "points": 2,
  "user": { "id": 3, "username": "bob" },
  "submission_id": 7,
  "parent_id": null,
  "created_at": "2026-11-20T11:00:00Z",
  "updated_at": "2026-11-20T11:00:00Z"
}
```
- `parent_id` és `null` en un comment directe a la submission, i l'id del comment pare en una resposta (és el que fa possible l'enllaç *parent*, COM-05).
- A l'arbre (`GET /submissions/{id}`, `GET /comments/{id}`) cada comment afegeix `"replies": [ ... ]` en ordre cronològic (buit si no n'hi ha).
- Als llistats plans (`GET /comments`, `/users/{id}/comments`, favorites, upvoted) afegeix `"submission": { "id": 7, "title": "..." }`.

### User
```json
{
  "id": 2,
  "username": "alice",
  "about": "Hi!",
  "karma": 25,
  "avatar_url": "https://.../avatar.png",
  "banner_url": "https://.../banner.png",
  "created_at": "2026-11-01T09:00:00Z"
}
```
**Mai** inclou l'`api-key`. L'`email` només es retorna a l'usuari propietari.

---

## 4. Exemples de peticions

```http
POST /api/v1/submissions
X-API-KEY: 9f2c...
Content-Type: application/json

{ "title": "Ask HN: Best Rails tutorial?" }
```
→ `201 Created` amb la submission (`submission_type: "ask"`).

```http
POST /api/v1/submissions/7/votes
X-API-KEY: 9f2c...
```
→ `201 Created` `{ "points": 13 }`; si ja havia votat → `409` (format de la secció 5).

---

## 5. Format d'error comú

Tots els errors (inclosos 401, 404 de ruta inexistent, 400 de JSON malformat i 500 d'error inesperat) tenen aquesta forma:

```json
{
  "error": "unprocessable_entity",
  "message": "Validation failed",
  "details": { "title": ["can't be blank"] }
}
```

| Camp | Tipus | Obligatori | Descripció |
|---|---|---|---|
| `error` | string | sí | Codi estable per a màquines: `bad_request`, `unauthorized`, `forbidden`, `not_found`, `conflict`, `unprocessable_entity`, `internal_server_error`. |
| `message` | string | sí | Explicació per a persones. |
| `details` | objecte | no | 422: errors per camp. 409: `existing_submission_id` si és una url duplicada. |

Compatible amb l'`ErrorResult` de la plantilla `wot-api.yaml` (que només exigeix `message`).
Implementat a `Api::V1::BaseController#render_error`; tots els controladors de l'API
han d'heretar-ne.

| Codi | Exemple de `message` |
|---|---|
| 400 | `Request body is not valid JSON` |
| 401 | `API key is missing or invalid` |
| 403 | `You can only modify your own submissions` |
| 404 | `Submission with id=99 not found` |
| 409 | `This URL has already been submitted` |
| 422 | `Validation failed` |
| 500 | `Internal server error` |

---

## 6. Correspondència amb les històries

| Història | Endpoints |
|---|---|
| API-03 | `GET /submissions` |
| API-04 | `POST /submissions` |
| API-05 | `GET /submissions/{id}` |
| API-06 | `PUT`, `DELETE /submissions/{id}` |
| API-07 | `POST /submissions/{id}/comments`, `POST /comments/{id}/replies` |
| API-08 | `GET /comments/{id}` |
| API-09 | `PUT`, `DELETE /comments/{id}` |
| API-10 | `GET /comments`, `GET /users/{id}/threads` |
| API-11 | `POST`, `DELETE .../votes` (submissions i comments) |
| API-12 | `POST`, `DELETE .../favorites` (submissions i comments) |
| API-13 | `POST`, `DELETE /submissions/{id}/hidden` |
| API-14 | `GET /users/{id}`, `/submissions`, `/comments`, `/favorites/*` |
| API-15 | `PUT /users/{id}` |
| API-16 | `PUT /users/{id}/images`, `DELETE /users/{id}/images/{kind}` |
| API-17 | `GET /users/{id}/upvoted/*`, `/hidden` |

---

## 7. Decisions a validar per l'equip

Criteri d'acceptació de REST-01: **el disseny ha de ser revisat per tot l'equip abans
d'implementar-lo**. Es proposa revisar-ho amb una PR on cada membre aprova (o comenta) les
decisions següents; un cop aprovada, es considera tancat i només es canvia per acord.

- [ ] Capçalera de l'api-key: `X-API-KEY` (alternativa: `Authorization`, com a la plantilla).
- [ ] Votar/favorit/amagar dues vegades → **409** (alternativa: idempotent, 200/204).
- [ ] Treure un vot/favorit/hidden que no existeix → **404** (alternativa: 204 com a la plantilla).
- [ ] `DELETE .../votes` retorna **200** amb els `points` (API-11) i no 204.
- [ ] Llistat de submissions amb un sol endpoint i `?list=` i `?q=` (alternativa: `/submissions/newest`, `/submissions/ask`...).
- [ ] Respondre amb `POST /comments/{id}/replies` i comentar amb `POST /submissions/{id}/comments` (alternativa: un sol endpoint amb `parent_id`).
- [ ] Nom del camp del text d'un comment: `body` (com al model) i no `text`.
- [ ] `threads` públic per a qualsevol usuari (com la web) i no només per a l'usuari de l'api-key.
- [ ] Pujada d'imatges a `PUT /users/{id}/images` separat del `PUT /users/{id}` perquè només aquest sigui `multipart/form-data`.
- [ ] **Canvi de comportament respecte a la web:** la web és idempotent (votar/amagar/marcar dues vegades, desvotar sense vot, o votar el contingut propi s'ignoren en silenci i redirigeixen), però l'API és estricta (409, 404 i 403) perquè un client d'API necessita saber si l'acció ha fet efecte. La web no canvia.
- [ ] El 409 de url duplicada no envia `Location`; n'hi ha prou amb `details.existing_submission_id`.
- [ ] Un verb no definit sobre una ruta existent respon 404 (no 405 amb `Allow`).
- [ ] Tot `/api/*` que no existeix respon 404 en JSON.
- [ ] Sense paginació.