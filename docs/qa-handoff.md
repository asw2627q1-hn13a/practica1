# QA Handoff — Hacker News clone (segon revisor)

**App desplegada:** https://practica1-65h7.onrender.com

Aquest document és per a un **segon revisor** que entra amb un **compte de GitHub diferent**
del d'en Marc (`Marc-PlanasBosch`), per poder provar les funcions de **vot**, que
necessiten dos usuaris.

---

## ⚠️ Abans de començar

La web pot estar servint un **build antic**. Confirma que s'ha fet un **redeploy recent**
abans de provar. Si SUB-03/04, logout o els avatars fallen, és molt probablement pel deploy
antic (ja estan al codi de `develop`/`main`) — **no ho tornis a reportar**.

**Login:** clica *login* (dalt a la dreta) i autentica't amb el compte de GitHub facilitat.

---

## Objectiu principal: provar el VOT (necessita 2 usuaris)

1. **ACT-03 — vot a submissions:** obre una submission creada per en Marc (p. ex. "QA url
   submission" a `/newest`). Ha d'aparèixer la **fletxa de vot (▲)**.
   - Vota → **+1 punt**. Recarrega → l'estat del vot **es manté**.
   - Torna a votar → **no** suma (màxim 1 vot per usuari i submission).
   - **Unvote** → resta el punt.
   - Comprova que **l'ordre de `/news`** reflecteix el canvi de punts.
2. **ACT-04 — vot a comments:** vota un **comentari d'un altre usuari** → fletxa visible,
   els **points** del comentari canvien, i l'estat persisteix en recarregar.
3. **No pots votar el teu propi contingut:** crea una submission i un comentari teus i
   confirma que **NO** surt la fletxa de vot en els teus.
4. **Favorite / Hide (des d'un 2n usuari):** favorite i un-favorite d'una submission d'altri;
   hide → surt de `news`/`newest`/`ask` per a tu i apareix a `/hidden` (prova l'unhide).
5. **Perfil:** entra al teu perfil i al d'en Marc (`/users/2`): comprova avatar/banner i els
   llistats d'activitat (submissions / comments / favorites — USR-07; upvoted / hidden al teu
   perfil — USR-08).

---

## Bugs JA coneguts — NO els tornis a reportar

- **Cercador → 404** (`/search`): SRC-01 **no implementat** (no hi ha ruta). *Bug real, pendent.*
- **Pendents de redeploy** (ja arreglats al codi de `develop`): URL invàlida s'acceptava
  (SUB-03), URL duplicada creava còpia (SUB-04), `/logout` donava 404, perfil sense
  avatar/banner per defecte, perfil sense llistats d'activitat.
- Formulari d'**editar submission** mostra camps interns (Points, User, Submission type);
  hauria de mostrar només Title / Url / Text.

---

## Notes

- Hi ha **dades de prova** del primer pas (submissions "QA ..." i alguns comentaris).
- **Què reportar:** qualsevol bug **nou**, sobretot del **vot** (comptatge de punts,
  1-vot-per-usuari, persistència en recarregar, ordenació a `/news`) i dels llistats de perfil.
