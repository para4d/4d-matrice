-- ================================================================
-- 4D SISTEMI INFORMATICI — Dati iniziali della matrice
-- Esegui DOPO schema.sql nel Supabase SQL Editor
-- ================================================================

insert into public.matrix_cells (id, sector_id, activity_index, coverage, label, items) values

-- ── SECURITY ────────────────────────────────────────────────────
('sec-0','sec',0,'full','Risk & compliance',
 '[{"n":"NIS2 assessment","d":"Gap analysis e roadmap compliance"},{"n":"Cybersecurity advisory","d":"Advisory & Strategy per CISO/management"},{"n":"Informatica forense","d":"Analisi post-incidente, raccolta prove"},{"n":"GDPR / ISO 27001","d":"Supporto normativo e certificazione"}]'::jsonb),

('sec-1','sec',1,'full','Architettura security',
 '[{"n":"Security design","d":"Threat modeling e architettura difensiva"},{"n":"Segmentazione rete","d":"VLAN, Zero Trust, DMZ"},{"n":"SOC design","d":"Definizione processi e strumenti SOC"}]'::jsonb),

('sec-2','sec',2,'full','Soluzioni security',
 '[{"n":"WatchGuard","d":"Firewall UTM, Wi-Fi sicuro, MFA"},{"n":"EDR / EPDR","d":"Antivirus evoluto per endpoint"},{"n":"SOC as a Service","d":"Monitoraggio H24 tramite partner"}]'::jsonb),

('sec-3','sec',3,'full','Deploy security',
 '[{"n":"Installazione firewall","d":"On-premise e cloud gateway"},{"n":"Endpoint protection","d":"Deploy e configurazione EDR su fleet"},{"n":"MFA rollout","d":"Attivazione multi-factor authentication"}]'::jsonb),

('sec-4','sec',4,'full','Monitoraggio continuo',
 '[{"n":"Care Time Security","d":"Interventi prioritari su incidenti"},{"n":"Presidio tecnico","d":"Tecnico dedicato in sede o remoto"},{"n":"Daily Monitoring","d":"NinjaOne alert e patch management"}]'::jsonb),

-- ── CONTINUITY ──────────────────────────────────────────────────
('con-0','con',0,'partial','Business continuity',
 '[{"n":"BC assessment","d":"Analisi RTO/RPO e criticità"},{"n":"DR planning","d":"Piano di disaster recovery documentato"}]'::jsonb),

('con-1','con',1,'partial','Architettura backup/DR',
 '[{"n":"Backup design","d":"Strategia 3-2-1, immutabilità, retention"},{"n":"Cloud DR","d":"Failover su cloud (Cielo/Azure)"}]'::jsonb),

('con-2','con',2,'partial','Soluzioni backup',
 '[{"n":"Backup on-premise","d":"NAS, tape, server dedicati Dell"},{"n":"Cloud backup","d":"Replicazione su Cielo Cloud"},{"n":"Veeam / Acronis","d":"Software backup enterprise (da confermare)"}]'::jsonb),

('con-3','con',3,'partial','Implementazione DR',
 '[{"n":"Deploy backup","d":"Configurazione agent e policy"},{"n":"Test restore","d":"Prove periodiche di ripristino"}]'::jsonb),

('con-4','con',4,'full','Manutenzione backup',
 '[{"n":"All-Inclusive","d":"Contratto omnicomprensivo con SLA"},{"n":"Monitoring backup","d":"Alert su job falliti e spazio"},{"n":"Care Activity","d":"Interventi programmati e verifiche"}]'::jsonb),

-- ── WORKPLACE ───────────────────────────────────────────────────
('wor-0','wor',0,'full','Advisory utenti',
 '[{"n":"Advisory & Strategy","d":"Digital workplace roadmap"},{"n":"Training & Enablement","d":"Formazione utenti e IT su M365"},{"n":"Assessment strumenti","d":"Audit degli strumenti in uso"}]'::jsonb),

('wor-1','wor',1,'full','Modern Workplace design',
 '[{"n":"M365 design","d":"Teams, SharePoint, Exchange Online"},{"n":"Cloud 3","d":"Architettura licenze e tenant M365"},{"n":"Mobile policy","d":"MDM, BYOD, Intune"}]'::jsonb),

('wor-2','wor',2,'full','Licenze e hardware',
 '[{"n":"Licenze M365","d":"CSP: Business / E3 / E5"},{"n":"PC & notebook Dell","d":"Workstation certificate e garantite"},{"n":"Periferiche","d":"Monitor, stampanti, cuffie, webcam"}]'::jsonb),

('wor-3','wor',3,'full','Setup utenti',
 '[{"n":"Deploy M365","d":"Migrazione mail, Teams, OneDrive"},{"n":"Setup workstation","d":"Imaging, policy GPO, join AD/AAD"},{"n":"Onboarding IT","d":"Creazione account e profili"}]'::jsonb),

('wor-4','wor',4,'full','Help desk',
 '[{"n":"Help Desk","d":"Supporto L1/L2 utenti"},{"n":"NinjaOne RMM","d":"Gestione remota endpoint"},{"n":"Care Activity","d":"Gestione ticket e attività programmate"}]'::jsonb),

-- ── INFRASTRUCTURE ──────────────────────────────────────────────
('inf-0','inf',0,'full','Infrastructure advisory',
 '[{"n":"Infrastructure assessment","d":"Analisi stato attuale e gap"},{"n":"Cloud strategy","d":"On-prem vs cloud vs ibrido"},{"n":"Capacity planning","d":"Dimensionamento carichi futuri"}]'::jsonb),

('inf-1','inf',1,'full','Network & server design',
 '[{"n":"Network design","d":"LAN/WAN, SD-WAN, VPN"},{"n":"Server & storage","d":"Virtualizzazione, HCI, SAN"},{"n":"Cloud architecture","d":"Cielo, Azure, hybrid cloud"}]'::jsonb),

('inf-2','inf',2,'full','Hardware e cloud',
 '[{"n":"Server Dell","d":"PowerEdge certificati ambienti critici"},{"n":"Switch / router","d":"Apparati di rete gestiti"},{"n":"Cielo Cloud","d":"IaaS italiano (partner certificato)"},{"n":"Storage NAS/SAN","d":"Dell e altri brand enterprise"}]'::jsonb),

('inf-3','inf',3,'full','Deploy infrastruttura',
 '[{"n":"Cabling & rack","d":"Cablaggi strutturati, armadi rack"},{"n":"Configurazione network","d":"VLAN, routing, wireless"},{"n":"Virtualizzazione","d":"VMware / Hyper-V setup"}]'::jsonb),

('inf-4','inf',4,'full','Gestione IT',
 '[{"n":"NinjaOne","d":"RMM: monitoring, patch, alert"},{"n":"Daily & Monitoring","d":"Presidio infrastruttura quotidiano"},{"n":"Reperibilità","d":"Tecnico on-call H24"},{"n":"All-Inclusive","d":"Contratto full-managed"}]'::jsonb),

-- ── MANAGEMENT ──────────────────────────────────────────────────
('man-0','man',0,'partial','Digital transformation',
 '[{"n":"Business analysis","d":"Analisi processi e requisiti"},{"n":"Digital transformation","d":"Roadmap digitalizzazione PMI"}]'::jsonb),

('man-1','man',1,'full','Software design',
 '[{"n":"Software su misura","d":"Sviluppo applicazioni custom"},{"n":"iSiAP design","d":"Configurazione suite per retail/ristorazione"},{"n":"CTZON design","d":"Gestione cantieri e manutenzione"},{"n":"Web & digital","d":"Digital Experience & Web Solutions"}]'::jsonb),

('man-2','man',2,'full','Soluzioni gestionali',
 '[{"n":"iSiAP","d":"Suite per ristorazione e retail"},{"n":"EdiTime","d":"Rilevazione presenze e HR"},{"n":"DegustApp","d":"App per ristorazione e degustazione"},{"n":"CTZON","d":"Gestione cantieri e manutenzione impianti"},{"n":"Industrial Connect","d":"IoT e collegamento macchinari"}]'::jsonb),

('man-3','man',3,'partial','Deploy applicativi',
 '[{"n":"Installazione software","d":"Setup e configurazione gestionali"},{"n":"Migrazione dati","d":"Import da sistemi legacy"},{"n":"Integrazione","d":"API e connettori con altri sistemi"}]'::jsonb),

('man-4','man',4,'partial','Supporto applicativo',
 '[{"n":"Supporto iSiAP/EdiTime","d":"Help desk applicativo"},{"n":"Aggiornamenti","d":"Release update e patch applicative"},{"n":"Retail support","d":"Servizi dedicati al canale retail"}]'::jsonb)

on conflict (id) do nothing;
