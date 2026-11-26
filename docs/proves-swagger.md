# Proves de l'API des de l'editor de Swagger (DOC-02)

Llista per executar **tots els endpoints** des de https://editor.swagger.io contra l'aplicació
desplegada a Render, amb l'api-key d'un usuari real (criteri d'acceptació de DOC-02). També serveix
d'assaig per a la demo (DOC-04).

Les proves van en ordre: les primeres creen dades que les següents fan servir, i l'última neteja
el que s'ha creat. Si una resposta no coincideix amb la columna **Esperat**, apunta'n el codi i el
cos a la columna **Resultat**.

---

## 0. Preparació

1. **Desperta Render.** El pla gratuït s'adorm: obre https://practica1-65h7.onrender.com i espera
   que carregui (pot trigar ~1 minut). Si no, la primera crida de Swagger falla per temps.
2. **Fes login a la web** amb GitHub i, al teu perfil, **copia l'api-key**. Apunta també el teu
   **id d'usuari** (és a l'URL del perfil, `/users/<id>`).
3. **Carrega l'api.yaml a Swagger:** *File → Import URL* i enganxa:
   `https://raw.githubusercontent.com/asw2627q1-hn13a/practica1/develop/api/api.yaml`
4. A dalt, a **Servers**, tria `https://practica1-65h7.onrender.com` (no `localhost`: des de
   Swagger, Chrome bloqueja `localhost` per *Local Network Access*).
5. Clica **Authorize**, enganxa l'api-key a `apiKey (X-API-KEY)` → *Authorize* → *Close*.
6. **Crea una submission teva des de la web** (*submit*), de tipus url, amb el títol
   `DOC-02 prova` i una url que no existeixi (p. ex. `https://example.com/doc02-<data>`).
   *(Quan entri API-04, la #52, es crearà des de Swagger: vegeu §7.)*

Durant les proves faràs servir aquests valors; apunta'ls aquí a mesura que els tinguis:

| Nom | Què és | D'on surt | Valor |
|---|---|---|---|
| `MEU_ID` | El teu id d'usuari | Pas 2 | |
| `S_MEVA` | La submission `DOC-02 prova` | Prova 1.2 (`newest`, la primera) | |
| `S_ALTRE` | Una submission **d'un altre usuari** | Prova 1.1 (`user.id` ≠ `MEU_ID`) | |
| `URL_ALTRE` | La `url` de `S_ALTRE` | Prova 1.1 | |
| `C_ALTRE` | Un comment **d'un altre usuari** | Prova 1.6 (`user.id` ≠ `MEU_ID`) | |
| `C_MEU` | El comment que crearàs | Prova 2.1 | |
| `R_MEU` | La resposta que crearàs | Prova 2.2 | |

Per als 404 fes servir un id que no existeixi: **`999999`**.

---

## 1. Llegir (submissions i comments)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 1.1 | `GET /submissions` (listSubmissions) | sense paràmetres | **200**, array de tipus `url` ordenat per `points` (de més a menys). Tria'n una d'un altre usuari → `S_ALTRE`, `URL_ALTRE` | |
| 1.2 | `GET /submissions` | `list=newest` | **200**, la primera és `DOC-02 prova` → `S_MEVA` | |
| 1.3 | `GET /submissions` | `list=ask` | **200**, només `submission_type: ask`, per data | |
| 1.4 | `GET /submissions` | `q=doc-02` (sense `list`) | **200**, hi surt `DOC-02 prova` (cerca el text dins del títol, sense distingir majúscules) | |
| 1.5 | `GET /submissions/{id}` (getSubmission) | `id=S_ALTRE` | **200**, la submission amb `comments` (arbre; `[]` si no en té) | |
| 1.6 | `GET /comments` (listComments) | — | **200**, del més recent al més antic; cada un amb `submission: {id, title}`. Tria'n un d'un altre usuari → `C_ALTRE` | |
| 1.7 | `GET /comments/{id}` (getComment) | `id=C_ALTRE` | **200**, el comment amb `replies` i `submission` | |
| 1.8 | `GET /users/{id}/threads` (listUserThreads) | `id` = l'autor de `C_ALTRE` | **200**, els seus comments amb `replies` (respostes directes) | |

## 2. Crear comments i respostes

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 2.1 | `POST /submissions/{submissionId}/comments` (addComment) | `submissionId=S_MEVA`, cos `{"body": "Comment de prova DOC-02"}` | **201**, `parent_id: null`, `user.id = MEU_ID` → `C_MEU` | |
| 2.2 | `POST /comments/{commentId}/replies` (replyToComment) | `commentId=C_MEU`, cos `{"body": "Resposta de prova DOC-02"}` | **201**, `parent_id = C_MEU`, `submission_id = S_MEVA` → `R_MEU` | |
| 2.3 | `GET /submissions/{id}` | `id=S_MEVA` | **200**, `comments` = [`C_MEU` amb `replies` = [`R_MEU`]] | |
| 2.4 | `GET /comments/{id}` | `id=C_MEU` | **200**, `replies` = [`R_MEU`], `submission.title = "DOC-02 prova"` | |
| 2.5 | `GET /users/{id}/threads` | `id=MEU_ID` | **200**, el primer és `R_MEU`; `C_MEU` hi és amb `replies` = [`R_MEU`] | |
| 2.6 | `GET /comments` | — | **200**, el primer és `R_MEU` | |

## 3. Editar la submission pròpia (API-06)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 3.1 | `PUT /submissions/{id}` (updateSubmission) | `id=S_MEVA`, cos `{"title": "DOC-02 prova editada"}` | **200**, títol nou; la `url` no canvia | |
| 3.2 | `PUT /submissions/{id}` | `id=S_MEVA`, cos `{"url": ""}` | **200**, `url: null`, `submission_type: ask` | |
| 3.3 | `PUT /submissions/{id}` | `id=S_MEVA`, cos `{"url": "https://example.com/doc02-<data>"}` | **200**, torna a ser `url` | |

## 4. Votes (API-11)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 4.1 | `POST /submissions/{submissionId}/votes` (voteSubmission) | `S_ALTRE` | **201**, `{"points": N+1}` (N = els points de la prova 1.1) | |
| 4.2 | `POST /submissions/{submissionId}/votes` | `S_ALTRE` (un altre cop) | **409** `conflict`, *"You have already voted this submission"* | |
| 4.3 | `DELETE /submissions/{submissionId}/votes` (unvoteSubmission) | `S_ALTRE` | **200**, `{"points": N}` | |
| 4.4 | `DELETE /submissions/{submissionId}/votes` | `S_ALTRE` (un altre cop) | **404**, *"You have not voted this submission"* | |
| 4.5 | `POST /submissions/{submissionId}/votes` | `S_MEVA` | **403**, *"You cannot vote your own submission"* | |
| 4.6 | `POST /comments/{commentId}/votes` (voteComment) | `C_ALTRE` | **201**, `{"points": …}` | |
| 4.7 | `DELETE /comments/{commentId}/votes` (unvoteComment) | `C_ALTRE` | **200**, els points tornen a ser els d'abans | |
| 4.8 | `POST /comments/{commentId}/votes` | `C_MEU` | **403**, *"You cannot vote your own comment"* | |

## 5. Favorites (API-12)

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 5.1 | `POST /submissions/{submissionId}/favorites` (favoriteSubmission) | `S_ALTRE` | **201**, `{"favorited": true}` | |
| 5.2 | `POST /submissions/{submissionId}/favorites` | `S_ALTRE` (un altre cop) | **409**, *"This submission is already in your favorites"* | |
| 5.3 | `DELETE /submissions/{submissionId}/favorites` (unfavoriteSubmission) | `S_ALTRE` | **204**, sense cos | |
| 5.4 | `DELETE /submissions/{submissionId}/favorites` | `S_ALTRE` (un altre cop) | **404**, *"This submission is not in your favorites"* | |
| 5.5 | `POST /comments/{commentId}/favorites` (favoriteComment) | `C_MEU` (el propi també es pot) | **201**, `{"favorited": true}` | |
| 5.6 | `DELETE /comments/{commentId}/favorites` (unfavoriteComment) | `C_MEU` | **204** | |

## 6. Errors

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 6.1 | `GET /submissions` | `list=top` | **400**, *"Invalid 'list' value: top. Allowed: news, newest, ask."* | |
| 6.2 | `GET /submissions/{id}` | `id=999999` | **404**, *"Submission with id=999999 not found"* | |
| 6.3 | `GET /comments/{id}` | `id=999999` | **404**, *"Comment with id=999999 not found"* | |
| 6.4 | `GET /users/{id}/threads` | `id=999999` | **404**, *"User with id=999999 not found"* | |
| 6.5 | `POST /submissions/{submissionId}/comments` | `submissionId=999999`, cos `{"body": "x"}` | **404** | |
| 6.6 | `POST /comments/{commentId}/replies` | `commentId=999999`, cos `{"body": "x"}` | **404** | |
| 6.7 | `POST /submissions/{submissionId}/votes` | `999999` | **404** | |
| 6.8 | `POST /submissions/{submissionId}/comments` | `submissionId=S_MEVA`, cos `{"body": "   "}` | **422**, `details: {"body": ["can't be blank"]}` | |
| 6.9 | `PUT /submissions/{id}` | `id=S_MEVA`, cos `{"title": ""}` | **422**, `details: {"title": ["can't be blank"]}` | |
| 6.10 | `PUT /submissions/{id}` | `id=S_MEVA`, cos `{"url": "example.com"}` | **422**, `details.url` | |
| 6.11 | `PUT /submissions/{id}` | `id=S_MEVA`, cos `{"url": "URL_ALTRE"}` | **409**, `details: {"existing_submission_id": S_ALTRE}` | |
| 6.12 | `PUT /submissions/{id}` | `id=S_MEVA`, cos escrit a mà: `{"title":` (JSON mal format) | **400**, *"Request body is not valid JSON"* | |
| 6.13 | `PUT /submissions/{id}` | `id=S_ALTRE`, cos `{"title": "x"}` | **403**, *"You can only modify your own submissions"*; `S_ALTRE` no canvia | |
| 6.14 | `DELETE /submissions/{id}` (deleteSubmission) | `id=S_ALTRE` — **comprova abans que NO és teva** | **403**; no s'esborra res | |
| 6.15 | Qualsevol (p. ex. `GET /submissions`) | **Authorize → Logout** (sense api-key) | **401**, *"API key is missing or invalid"*. Després torna a fer *Authorize* | |
| 6.16 | Qualsevol | *Authorize* amb una api-key inventada | **401** | |

## 7. Neteja

| # | Operació | Entrada | Esperat | Resultat |
|---|---|---|---|---|
| 7.1 | `DELETE /submissions/{id}` | `id=S_MEVA` | **204**; s'esborren també `C_MEU` i `R_MEU` | |
| 7.2 | `GET /submissions/{id}` | `id=S_MEVA` | **404** | |
| 7.3 | `GET /comments/{id}` | `id=C_MEU` | **404** (s'ha esborrat amb la submission) | |

Comprova també que `S_ALTRE` i `C_ALTRE` tenen els mateixos points que al principi (els vots
s'han tret a les proves 4.3 i 4.7).

---

## 8. Pendents: quan entrin a `develop` i a Render

| Endpoint | HU / PR | Proves que caldrà afegir |
|---|---|---|
| `POST /submissions` (createSubmission) | API-04, #52 | Crear `S_MEVA` des d'aquí en lloc de la web (201); url repetida → 409; sense `title` → 422; sense `url` → tipus `ask` |
| `PUT`, `DELETE /comments/{id}` | API-09, #49 | Editar `C_MEU` (200), el d'un altre (403), esborrar `R_MEU` (204) |
| `POST`, `DELETE /submissions/{id}/hidden` | API-13 | Amagar `S_ALTRE` (201) i comprovar que no surt a `GET /submissions`; mostrar-la (204) |
| `GET /users/{id}`, `/submissions`, `/comments`, `/favorites/*` | API-14 | Perfil i activitat de `MEU_ID` i d'un altre usuari |
| `PUT /users/{id}` | API-15 | Editar el `about` propi (200) i el d'un altre (403) |
| `PUT`, `DELETE /users/{id}/images…` | API-16 | Pujar avatar i banner (multipart) i tornar als per defecte |
| `GET /users/{id}/hidden`, `/upvoted/*` | API-17 | Els propis (200) i els d'un altre (403) |

> A Render hi ha l'API però a `main` no, de manera que Render desplega `develop` (confirmeu-ho al
> tauler de Render). Després de cada fusió, comprova a *Events* que el desplegament ha acabat abans
> de repetir les proves.
