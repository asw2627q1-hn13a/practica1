# Proves de l'API des de l'editor de Swagger (DOC-02)

Llista per executar **tots els endpoints** des de https://editor.swagger.io contra l'aplicació
desplegada a Render, amb l'api-key d'un usuari real (criteri d'acceptació de DOC-02). També serveix
d'assaig per a la demo (DOC-04).

Les proves van en ordre: les primeres creen dades que les següents fan servir, i l'última secció
neteja el que s'ha creat. Si una resposta no coincideix amb la columna **Esperat**, apunta'n el codi
i el cos a la columna **Resultat**.

---

## 0. Preparació

1. **Desperta Render.** El pla gratuït s'adorm: obre https://practica1-65h7.onrender.com i espera
   que carregui (pot trigar ~1 minut). Si no, la primera crida de Swagger falla per temps.
2. **Fes login a la web** amb GitHub i, al teu perfil, **copia l'api-key**. Apunta també el teu
   **id d'usuari** (és a l'URL del perfil, `/users/<id>`) i el teu **about** actual (la secció 9 el
   canvia i al final el tornaràs a posar).
3. **Carrega l'api.yaml a Swagger:** *File → Import URL* i enganxa:
   `https://raw.githubusercontent.com/asw2627q1-hn13a/practica1/develop/api/api.yaml`
4. A dalt, a **Servers**, tria `https://practica1-65h7.onrender.com` (no `localhost`: des de
   Swagger, Chrome bloqueja `localhost` per *Local Network Access*).
5. Clica **Authorize**, enganxa l'api-key a `apiKey (X-API-KEY)` → *Authorize* → *Close*.
6. Tingues a mà una **imatge PNG o JPEG petita** (per a la secció 10) i un **fitxer que no sigui
   una imatge** (p. ex. un `.txt`).

> ⚠️ La secció 10 canvia el teu avatar i el torna a la imatge per defecte. Si en tens un de propi,
> torna'l a pujar al final des de la web.

Durant les proves faràs servir aquests valors; apunta'ls aquí a mesura que els tinguis:

| Nom | Què és | D'on surt | Valor |
|---|---|---|---|
| `MEU_ID` | El teu id d'usuari | Pas 2 | |
| `ABOUT_ORIG` | El teu about abans de les proves | Pas 2 | |
| `S_MEVA` | La submission `DOC-02 prova` | Prova 1.1 | |
| `URL_MEVA` | La url de `S_MEVA` | Prova 1.1 | |
| `S_ASK` | La submission ask de prova | Prova 1.2 | |
| `S_ALTRE` | Una submission **d'un altre usuari** | Prova 2.1 (`user.id` ≠ `MEU_ID`) | |
| `ALTRE_ID` | L'autor de `S_ALTRE` | Prova 2.1 (`user.id`) | |
| `URL_ALTRE` | La `url` de `S_ALTRE` | Prova 2.1 | |
| `C_ALTRE` | Un comment **d'un altre usuari** | Prova 2.6 (`user.id` ≠ `MEU_ID`) | |
| `C_MEU` | El comment que crearàs | Prova 3.1 | |
| `R_MEU` | La resposta que crearàs | Prova 3.2 | |

Per als 404 fes servir un id que no existeixi: **`999999`**.

---

## 1. Crear submissions (API-04)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 1.1 | `POST /submissions` (createSubmission) | `{"title": "DOC-02 prova", "url": "https://example.com/doc02-<data>"}` (una url que no existeixi) | **201**, `submission_type: url`, `user.id = MEU_ID`, `points: 0` → `S_MEVA`, `URL_MEVA` | |
| 1.2 | `POST /submissions` | `{"title": "DOC-02 ask", "text": "Pregunta de prova"}` | **201**, `submission_type: ask`, `url: null` → `S_ASK` | |
| 1.3 | `POST /submissions` | `{"title": "Repetida", "url": "URL_MEVA"}` | **409**, `details: {"existing_submission_id": S_MEVA}`; no es crea res | |
| 1.4 | `POST /submissions` | `{"url": "https://example.com/sense-titol"}` | **422**, `details: {"title": ["can't be blank"]}` | |
| 1.5 | `POST /submissions` | `{"title": "Url dolenta", "url": "example.com"}` | **422**, `details.url` | |

## 2. Llegir (submissions i comments)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 2.1 | `GET /submissions` (listSubmissions) | sense paràmetres | **200**, array de tipus `url` ordenat per `points` (de més a menys). Tria'n una d'un altre usuari → `S_ALTRE`, `ALTRE_ID`, `URL_ALTRE` | |
| 2.2 | `GET /submissions` | `list=newest` | **200**, les primeres són `DOC-02 ask` i `DOC-02 prova` | |
| 2.3 | `GET /submissions` | `list=ask` | **200**, només `submission_type: ask`; hi surt `DOC-02 ask` | |
| 2.4 | `GET /submissions` | `q=doc-02` (sense `list`) | **200**, hi surten les dues `DOC-02` (cerca el text dins del títol, sense distingir majúscules) | |
| 2.5 | `GET /submissions/{id}` (getSubmission) | `id=S_ALTRE` | **200**, la submission amb `comments` (arbre; `[]` si no en té) | |
| 2.6 | `GET /comments` (listComments) | — | **200**, del més recent al més antic; cada un amb `submission: {id, title}`. Tria'n un d'un altre usuari → `C_ALTRE` | |
| 2.7 | `GET /comments/{id}` (getComment) | `id=C_ALTRE` | **200**, el comment amb `replies` i `submission` | |
| 2.8 | `GET /users/{id}/threads` (listUserThreads) | `id` = l'autor de `C_ALTRE` | **200**, els seus comments amb `replies` (respostes directes) | |

## 3. Crear comments i respostes (API-07, API-08)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 3.1 | `POST /submissions/{submissionId}/comments` (addComment) | `submissionId=S_MEVA`, `{"body": "Comment de prova DOC-02"}` | **201**, `parent_id: null`, `user.id = MEU_ID` → `C_MEU` | |
| 3.2 | `POST /comments/{commentId}/replies` (replyToComment) | `commentId=C_MEU`, `{"body": "Resposta de prova DOC-02"}` | **201**, `parent_id = C_MEU`, `submission_id = S_MEVA` → `R_MEU` | |
| 3.3 | `GET /submissions/{id}` | `id=S_MEVA` | **200**, `comments` = [`C_MEU` amb `replies` = [`R_MEU`]] | |
| 3.4 | `GET /comments/{id}` | `id=C_MEU` | **200**, `replies` = [`R_MEU`], `submission.title = "DOC-02 prova"` | |
| 3.5 | `GET /users/{id}/threads` | `id=MEU_ID` | **200**, el primer és `R_MEU`; `C_MEU` hi és amb `replies` = [`R_MEU`] | |
| 3.6 | `GET /comments` | — | **200**, el primer és `R_MEU` | |

## 4. Editar la submission pròpia (API-06)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 4.1 | `PUT /submissions/{id}` (updateSubmission) | `id=S_MEVA`, `{"title": "DOC-02 prova editada"}` | **200**, títol nou; la `url` no canvia | |
| 4.2 | `PUT /submissions/{id}` | `id=S_MEVA`, `{"url": ""}` | **200**, `url: null`, `submission_type: ask` | |
| 4.3 | `PUT /submissions/{id}` | `id=S_MEVA`, `{"url": "URL_MEVA"}` | **200**, torna a ser `url` | |

## 5. Votes (API-11) i upvoted (API-17)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 5.1 | `POST /submissions/{submissionId}/votes` (voteSubmission) | `S_ALTRE` | **201**, `{"points": N+1}` (N = els points de la prova 2.1) | |
| 5.2 | `POST /submissions/{submissionId}/votes` | `S_ALTRE` (un altre cop) | **409**, *"You have already voted this submission"* | |
| 5.3 | `POST /comments/{commentId}/votes` (voteComment) | `C_ALTRE` | **201**, `{"points": …}` | |
| 5.4 | `GET /users/{id}/upvoted/submissions` (listUserUpvotedSubmissions) | `id=MEU_ID` | **200**, la primera és `S_ALTRE` | |
| 5.5 | `GET /users/{id}/upvoted/comments` (listUserUpvotedComments) | `id=MEU_ID` | **200**, el primer és `C_ALTRE`, amb `submission` | |
| 5.6 | `GET /users/{id}/upvoted/submissions` | `id=ALTRE_ID` | **403**, *"You can only see your own upvoted submissions"* | |
| 5.7 | `DELETE /submissions/{submissionId}/votes` (unvoteSubmission) | `S_ALTRE` | **200**, `{"points": N}` | |
| 5.8 | `DELETE /submissions/{submissionId}/votes` | `S_ALTRE` (un altre cop) | **404**, *"You have not voted this submission"* | |
| 5.9 | `DELETE /comments/{commentId}/votes` (unvoteComment) | `C_ALTRE` | **200**, els points tornen a ser els d'abans | |
| 5.10 | `POST /submissions/{submissionId}/votes` | `S_MEVA` | **403**, *"You cannot vote your own submission"* | |
| 5.11 | `POST /comments/{commentId}/votes` | `C_MEU` | **403**, *"You cannot vote your own comment"* | |

## 6. Favorites (API-12) i llistats de favorits (API-14)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 6.1 | `POST /submissions/{submissionId}/favorites` (favoriteSubmission) | `S_ALTRE` | **201**, `{"favorited": true}` | |
| 6.2 | `POST /submissions/{submissionId}/favorites` | `S_ALTRE` (un altre cop) | **409**, *"This submission is already in your favorites"* | |
| 6.3 | `POST /comments/{commentId}/favorites` (favoriteComment) | `C_MEU` (el propi també es pot) | **201**, `{"favorited": true}` | |
| 6.4 | `GET /users/{id}/favorites/submissions` (listUserFavoriteSubmissions) | `id=MEU_ID` | **200**, la primera és `S_ALTRE` | |
| 6.5 | `GET /users/{id}/favorites/comments` (listUserFavoriteComments) | `id=MEU_ID` | **200**, el primer és `C_MEU`, amb `submission` | |
| 6.6 | `DELETE /submissions/{submissionId}/favorites` (unfavoriteSubmission) | `S_ALTRE` | **204**, sense cos | |
| 6.7 | `DELETE /submissions/{submissionId}/favorites` | `S_ALTRE` (un altre cop) | **404**, *"This submission is not in your favorites"* | |
| 6.8 | `DELETE /comments/{commentId}/favorites` (unfavoriteComment) | `C_MEU` | **204** | |

## 7. Hidden (API-13 i API-17)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 7.1 | `POST /submissions/{submissionId}/hidden` (hideSubmission) | `S_ALTRE` | **201**, `{"hidden": true}` | |
| 7.2 | `GET /submissions` | sense paràmetres | **200**, `S_ALTRE` **no** hi surt | |
| 7.3 | `GET /submissions/{id}` | `id=S_ALTRE` | **200**: el detall es veu igualment (amagar només afecta els llistats) | |
| 7.4 | `GET /users/{id}/hidden` (listUserHidden) | `id=MEU_ID` | **200**, la primera és `S_ALTRE` | |
| 7.5 | `GET /users/{id}/hidden` | `id=ALTRE_ID` | **403**, *"You can only see your own hidden submissions"* | |
| 7.6 | `POST /submissions/{submissionId}/hidden` | `S_ALTRE` (un altre cop) | **409**, *"This submission is already hidden"* | |
| 7.7 | `DELETE /submissions/{submissionId}/hidden` (unhideSubmission) | `S_ALTRE` | **204**; torna a sortir a `GET /submissions` | |
| 7.8 | `DELETE /submissions/{submissionId}/hidden` | `S_ALTRE` (un altre cop) | **404**, *"This submission is not hidden"* | |

## 8. Perfils i activitat (API-14)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 8.1 | `GET /users/{id}` (getUser) | `id=MEU_ID` | **200**, amb `email`; **sense** api-key; `avatar_url` i `banner_url` absolutes | |
| 8.2 | `GET /users/{id}` | `id=ALTRE_ID` | **200**, **sense** `email` | |
| 8.3 | `GET /users/{id}/submissions` (listUserSubmissions) | `id=MEU_ID` | **200**, les primeres són `DOC-02 ask` i `DOC-02 prova editada` | |
| 8.4 | `GET /users/{id}/comments` (listUserComments) | `id=MEU_ID` | **200**, el primer és `R_MEU`; cada un amb `submission` | |

## 9. Editar el perfil propi (API-15)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 9.1 | `PUT /users/{id}` (updateUser) | `id=MEU_ID`, `{"about": "  Prova DOC-02  "}` | **200**, `about: "Prova DOC-02"` (sense els espais), amb `email` | |
| 9.2 | `PUT /users/{id}` | `id=MEU_ID`, `{"email": "no-es-un-email"}` | **422**, `details: {"email": ["is invalid"]}`; no canvia res | |
| 9.3 | `PUT /users/{id}` | `id=ALTRE_ID`, `{"about": "x"}` | **403**, *"You can only modify your own profile"* | |
| 9.4 | `PUT /users/{id}` | `id=MEU_ID`, `{"about": "ABOUT_ORIG"}` (o `null` si no en tenies) | **200**, el teu about de sempre | |

## 10. Avatar i banner (API-16)

A Swagger, aquestes operacions mostren un formulari `multipart/form-data` amb un botó per triar el
fitxer.

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 10.1 | `PUT /users/{id}/images` (uploadUserImages) | `id=MEU_ID`, `avatar` = la imatge | **200**, `avatar_url` nova (`/rails/active_storage/...`) | |
| 10.2 | `PUT /users/{id}/images` | `id=MEU_ID`, `avatar` = el `.txt` | **422**, `details.avatar`; l'avatar no canvia | |
| 10.3 | `PUT /users/{id}/images` | `id=MEU_ID`, sense cap fitxer | **400**, *"Missing required parameter: avatar or banner"* | |
| 10.4 | `PUT /users/{id}/images` | `id=ALTRE_ID`, `avatar` = la imatge | **403**, *"You can only modify your own profile"* | |
| 10.5 | `DELETE /users/{id}/images/{kind}` (resetUserImage) | `id=MEU_ID`, `kind=avatar` | **200**, `avatar_url` torna a ser `default_avatar-….png` | |
| 10.6 | `DELETE /users/{id}/images/{kind}` | `id=MEU_ID`, `kind=foo` | **404**, *"Image with id=foo not found"* | |

## 11. Errors comuns

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 11.1 | `GET /submissions` | `list=top` | **400**, *"Invalid 'list' value: top. Allowed: news, newest, ask."* | |
| 11.2 | `GET /submissions/{id}` | `id=999999` | **404**, *"Submission with id=999999 not found"* | |
| 11.3 | `GET /comments/{id}` | `id=999999` | **404**, *"Comment with id=999999 not found"* | |
| 11.4 | `GET /users/{id}` | `id=999999` | **404**, *"User with id=999999 not found"* | |
| 11.5 | `POST /submissions/{submissionId}/comments` | `submissionId=999999`, `{"body": "x"}` | **404** | |
| 11.6 | `POST /submissions/{submissionId}/votes` | `999999` | **404** | |
| 11.7 | `POST /submissions/{submissionId}/comments` | `submissionId=S_MEVA`, `{"body": "   "}` | **422**, `details: {"body": ["can't be blank"]}` | |
| 11.8 | `PUT /submissions/{id}` | `id=S_MEVA`, `{"title": ""}` | **422**, `details: {"title": ["can't be blank"]}` | |
| 11.9 | `PUT /submissions/{id}` | `id=S_MEVA`, `{"url": "URL_ALTRE"}` | **409**, `details: {"existing_submission_id": S_ALTRE}` | |
| 11.10 | `PUT /submissions/{id}` | `id=S_MEVA`, cos escrit a mà: `{"title":` (JSON mal format) | **400**, *"Request body is not valid JSON"* | |
| 11.11 | `PUT /submissions/{id}` | `id=S_ALTRE`, `{"title": "x"}` | **403**, *"You can only modify your own submissions"*; `S_ALTRE` no canvia | |
| 11.12 | `DELETE /submissions/{id}` (deleteSubmission) | `id=S_ALTRE` — **comprova abans que NO és teva** | **403**; no s'esborra res | |
| 11.13 | Qualsevol (p. ex. `GET /submissions`) | **Authorize → Logout** (sense api-key) | **401**, *"API key is missing or invalid"*. Després torna a fer *Authorize* | |
| 11.14 | Qualsevol | *Authorize* amb una api-key inventada | **401** | |

## 12. Neteja

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 12.1 | `DELETE /submissions/{id}` | `id=S_ASK` | **204** | |
| 12.2 | `DELETE /submissions/{id}` | `id=S_MEVA` | **204**; s'esborren també `C_MEU` i `R_MEU` | |
| 12.3 | `GET /submissions/{id}` | `id=S_MEVA` | **404** | |
| 12.4 | `GET /comments/{id}` | `id=C_MEU` | **404** (s'ha esborrat amb la submission) | |

Comprova també que `S_ALTRE` i `C_ALTRE` tenen els mateixos points que al principi (els vots
s'han tret a les proves 5.7 i 5.9), que el teu about és `ABOUT_ORIG` i, si tenies un avatar propi,
torna'l a pujar des de la web.

---

## 13. Pendent: quan entri a `develop` i a Render

| Endpoint | HU / PR | Proves que caldrà afegir |
|---|---|---|
| `PUT`, `DELETE /comments/{id}` | API-09, #49 | Editar `C_MEU` (200), el d'un altre (403), `body` buit (422), esborrar `R_MEU` (204) |

> A Render hi ha l'API però a `main` no, de manera que Render desplega `develop` (confirmeu-ho al
> tauler de Render). Després de cada fusió, comprova a *Events* que el desplegament ha acabat abans
> de repetir les proves.
