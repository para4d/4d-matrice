# Matrice Servizi 4D Sistemi — Guida al deploy

## Cosa otterrai
Una web app accessibile da browser con:
- Login sicuro con email e password
- Matrice interattiva dei 5 settori x 5 attivita
- Suggerimenti: ogni collaboratore puo proporre modifiche
- Pannello Admin: approva/rifiuta suggerimenti, gestisce i ruoli
- Ruoli: viewer (solo lettura) / contributor (suggerisce) / admin (approva e modifica)

---

## PASSO 1 — Crea il progetto Supabase

1. Vai su https://supabase.com -> Start your project
2. Crea un nuovo progetto:
   - Nome: 4d-matrice
   - Password database: scegli una password sicura
   - Regione: West EU (Ireland)
3. Attendi ~2 minuti che il progetto sia pronto

---

## PASSO 2 — Crea le tabelle

1. Supabase -> SQL Editor (icona terminale a sinistra)
2. Copia tutto il contenuto di supabase/schema.sql
3. Incollalo e clicca Run
4. Ripeti con supabase/seed.sql

---

## PASSO 3 — Configura js/config.js

1. Supabase -> Settings -> API
2. Copia Project URL e anon/public key
3. Apri js/config.js e sostituisci i placeholder:

   const SUPABASE_URL  = 'https://IL-TUO-PROGETTO.supabase.co'
   const SUPABASE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5...'

---

## PASSO 4 — Carica su GitHub

1. Vai su https://github.com -> New repository
2. Nome: 4d-matrice, visibilita: Private
3. Carica tutti i file del progetto

---

## PASSO 5 — Deploy su Vercel

1. Vai su https://vercel.com -> Add New Project
2. Connetti GitHub, seleziona 4d-matrice
3. Clicca Deploy
4. Riceverai un URL tipo https://4d-matrice.vercel.app

Per un dominio personalizzato (es. matrice.4dsistemi.it):
Vercel -> Domains -> aggiungi il dominio

---

## PASSO 6 — Crea il primo admin

Esegui nel Supabase SQL Editor:

   update public.profiles
   set role = 'admin'
   where email = 'tua-email@4dsistemi.it';

Poi da admin puoi gestire gli altri utenti dall'interfaccia web.

---

## PASSO 7 — Disabilita conferma email (opzionale)

Per accesso immediato senza conferma email:
Supabase -> Authentication -> Providers -> Email -> disabilita "Confirm email"

---

## Struttura file

   4d-matrix/
   +-- index.html          Login e registrazione
   +-- matrix.html         Matrice interattiva
   +-- admin.html          Pannello amministratore
   +-- css/style.css       Stile condiviso
   +-- js/config.js        <-- MODIFICA con le tue credenziali
   +-- supabase/schema.sql Struttura database
   +-- supabase/seed.sql   Dati iniziali matrice
   +-- vercel.json         Configurazione hosting

---

## Ruoli

viewer      -> vede la matrice, non suggerisce
contributor -> vede e propone modifiche (default alla registrazione)
admin       -> approva/rifiuta, modifica direttamente, gestisce i ruoli

---

## Problemi comuni

"Invalid API key" -> Usa la chiave anon/public, non la service_role
Matrice vuota    -> Esegui seed.sql nel SQL Editor di Supabase
Email non arriva -> Controlla spam, o disabilita conferma (Passo 7)

---

## Aggiornare il sito

Modifica i file su GitHub: Vercel ridistribuisce automaticamente.
