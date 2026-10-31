# ocd-apex – Projektplan

## Architektur

```
Oracle Cloud Database
└── OCD Schema
    ├── ocd.api.* (ora* CODEDOC Framework)
    ├── v_ocd_packages (View für APEX)
    └── APEX Application
```

**Prinzip**: Alles im OCD Schema, keine Synonyme, direkte Zugriffe.

## Phase 1: MVP – Package Browser (Read-Only)

### User Stories

**US-1: Package-Liste anzeigen**
- Alle dokumentierten PL/SQL-Pakete auflisten
- Paketname, kurze Beschreibung, Status anzeigen
- Sortierung nach Name
- Paginierung für große Mengen

**US-2: Paketdetails anzeigen**
- Klick auf Paket → Detailseite (P2)
- Gliederung:
  - Paketübersicht (Name, Beschreibung, Status)
  - Funktionen (Tabelle: Name, Parameter, Return Type, Beschreibung)
  - Prozeduren (Tabelle: Name, Parameter, Beschreibung)
- Breadcrumb: Home → Paket

**US-3: Suchfunktion**
- Suchfeld auf Startseite
- Echtzeit-Filter in Paketliste
- Suche in Paketnamen und Beschreibungen

**US-4: Fehlerbehandlung**
- Paket nicht gefunden → Error-Seite
- Ungültige Parameter → Error-Seite

### APEX Seiten

| Seite | Name | Typ | Inhalt |
|-------|------|-----|--------|
| P1 | Home / Package List | Interactive Report | Alle Pakete, Suchfeld, Link zu P2 |
| P2 | Package Details | Multiple Regions | Overview, Functions, Procedures |
| P3 | Error | Static Content | "Package not found" |

### SQL-Queries

**Paketliste:**
```sql
SELECT 
  json_value(pkg_data, '$.name') as name,
  json_value(pkg_data, '$.description') as description,
  json_value(pkg_data, '$.status') as status
FROM v_ocd_packages
ORDER BY name;
```

**Package-Details:**
```sql
SELECT pkg_data 
FROM v_ocd_packages 
WHERE json_value(pkg_data, '$.name') = :P2_PACKAGE_NAME;
```

**Funktionen aus Package:**
```sql
SELECT 
  json_value(func, '$.name') as name,
  json_value(func, '$.description') as description,
  json_value(func, '$.return_type') as return_type,
  json_query(func, '$.parameters') as parameters
FROM v_ocd_packages,
  JSON_TABLE(pkg_data, '$.functions[*]' COLUMNS (func PATH '$'))
WHERE json_value(pkg_data, '$.name') = :P2_PACKAGE_NAME
ORDER BY name;
```

## Phase 2: Erweiterungen (optional)

- [ ] Syntax-Highlighting für PL/SQL Parameter-Types
- [ ] Hierarchie-View (Baum-Struktur für Funktionen/Prozeduren)
- [ ] PDF/HTML-Export
- [ ] REST-API über ORDS

## Phase 3: Bearbeitung (optional)

- [ ] Beschreibungen editierbar in APEX
- [ ] Speichern zurück in ocd-Datenstrukturen
- [ ] Versioning für Package-Snapshots

## Zeitplan

- **Week 1**: DB-Setup (✅) + APEX-Grundgerüst
- **Week 2**: P1 (List) + P2 (Details)
- **Week 3**: P3 (Error) + Suchfunktion + Testing
- **Week 4+**: Polishing, Phase 2 Features
