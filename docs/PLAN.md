# ocd-apex – Projektplan

## Architektur

```
Oracle Cloud Database
└── OCD Schema
    ├── ocd.api.* (ora* CODEDOC Framework)
    ├── Tabelle ocd_apex_schema        (Schemas, deren Packages die App zeigt)
    ├── Views
    │   ├── ocd_apex_package_docs      (je Package der Schemas das JSON aus ocd.api.information)
    │   ├── ocd_apex_components        ($.components[*] als Zeilen)
    │   └── ocd_apex_component_params  ($.components[*].parameters[*] als Zeilen)
    ├── Package ocd_apex_util          (Inspect-Helfer, HTML-Rendering der Doku)
    └── APEX Application 128
```

**Prinzip**: Alles im OCD Schema, keine Synonyme, direkte Zugriffe.
Die App zeigt die Packages der Schemas aus `ocd_apex_schema`. Package-Liste und
Quelltext fremder Schemas liest `ocd.worker` (`schema_packages`, `object_code`)
mit seiner Rolle `SELECT_CATALOG_ROLE`; die App selbst braucht keine Dictionary-Rechte.

Läuft die APEX-App mit einem anderen Parsing Schema, braucht dieses:

```sql
-- im OCD Schema
grant select on ocd_apex_package_docs to <APEX_SCHEMA>;
grant select on ocd_apex_components to <APEX_SCHEMA>;
grant select on ocd_apex_component_params to <APEX_SCHEMA>;
grant execute on ocd_apex_util to <APEX_SCHEMA>;
```

## MVP – Package Browser (Read-Only)

### User Stories

**US-1: Package-Liste anzeigen** ✅
- Alle PL/SQL-Pakete des Schemas auflisten
- Paketname und Beschreibung anzeigen
- Sortierung und Paginierung über den Interactive Report
- Button „Inspect all packages“ ruft `ocd_apex_util.inspect_all_packages` auf

**US-2: Paketdetails anzeigen** ✅
- Klick auf Paket → Detailseite (P2)
- Aufbau wie die Oracle PL/SQL Packages Reference:
  - Beschreibung
  - Constants, Subtypes, Types (mit Fields), Exceptions
  - Übersicht der Subprograms
  - je Subprogram: Beschreibung, Syntax, Parameter, Examples
- OCDs-Formatierung: Backticks, Absätze, URLs (optional mit `[Namen]`), `[[PACKAGE.COMPONENT]]` als Link mit Anker
- Copy-Button für Syntax und Examples
- Back-Button in der Titelleiste und am Seitenende
- Breadcrumb: Home → Package Details

**US-3: Suchfunktion** ✅
- Suchfeld auf Startseite
- Filter bei jeder Eingabe (Dynamic Action auf `keyup`)
- Suche in Paketnamen und Beschreibungen

**US-5: Schemas auswählen** ✅
- Seite „Schemas“ (P4) für angemeldete User, Shuttle mit allen Schemas aus `all_users` ohne `oracle_maintained`
- Auswahl gilt global (Tabelle `ocd_apex_schema`), Vorbild ist die Seite „Schema Check“ von occ-apex
- „Inspect all packages“ dokumentiert alle Packages der ausgewählten Schemas
- Package-Liste, Detailseite und Links `[[SCHEMA.PACKAGE]]` berücksichtigen das Schema

**US-4: Fehlerbehandlung** ✅
- Paket nicht gefunden → Error-Seite (P3)
- Manipulierte URL-Parameter → von APEX abgewiesen (Page Access Protection mit Checksumme)

### APEX Seiten

| Seite | Name | Typ | Inhalt |
|-------|------|-----|--------|
| P1 | Package Browser | Interactive Report | Alle Pakete, Suchfeld, Link zu P2 |
| P2 | Package Details | Dynamic Content | Doku aus `ocd_apex_util.package_html`, JSON-Quelle zum Aufklappen |
| P3 | Error | Static Content | „Package not found or not documented“ |
| P4 | Schemas | Shuttle | Auswahl der Schemas, nur für angemeldete User |

### SQL-Queries

**Paketliste (P1):**
```sql
select schema_name,
       object_name,
       json_value(pkg_data, '$.name') as name,
       json_value(pkg_data, '$.desc') as description
  from ocd_apex_package_docs;
```

**Package-Details (P2):**
```sql
select ocd_apex_util.package_html(:P2_PACKAGE_NAME, :P2_SCHEMA_NAME) from dual;
```

**Komponenten eines Packages:**
```sql
select comp_name, comp_type, comp_desc, syntax
  from ocd_apex_components
 where schema_name = :P2_SCHEMA_NAME
   and object_name = :P2_PACKAGE_NAME
 order by comp_seq;
```

## Weitere Ideen

**Darstellung**
- [ ] Syntax-Highlighting für Syntax und Examples
- [ ] Hierarchie-View (Baum-Struktur für Komponenten)
- [ ] Deprecation-Hinweise anzeigen (`pragma deprecate`); setzt voraus, dass `ocd.api.information` sie im JSON liefert
- [x] Packages anderer Schemas anzeigen (Seite „Schemas“)

**Performance**

Jede Abfrage auf `ocd_apex_package_docs` ruft `ocd.api.information` einmal je Package auf, P1 also für alle Packages der ausgewählten Schemas. Für kleine bis mittlere Schemas reicht das.
- [ ] JSON in einer Tabelle cachen, aktualisiert nach `inspect`
- [ ] alternativ Materialized View mit regelmäßigem Refresh
- [ ] HTTP-Caching, falls eine REST-API dazukommt

**Export und Schnittstellen**
- [ ] PDF/HTML-Export
- [ ] REST-API über ORDS

**Bearbeitung**
- [ ] Beschreibungen in APEX bearbeiten
- [ ] Speichern über `content_revision` (`modified_comment_or_code`, `priority_fl`), das `ocd.api.information` bereits auswertet
- [ ] Versioning für Package-Snapshots
