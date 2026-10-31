# Technische Architektur – ocd-apex

## Überblick

```
┌─────────────────────────────────────────────────────────────┐
│                   Oracle APEX 26.1.4                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  APEX App (OCD Workspace)                            │  │
│  │  - P1: Package List                                  │  │
│  │  - P2: Package Details                               │  │
│  │  - P3: Error Handling                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓ (SQL)
┌─────────────────────────────────────────────────────────────┐
│              OCD Schema                                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  v_ocd_packages (View)                               │  │
│  │  SELECT object_name, ocd.api.information() as json  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│  ocd.api.information() – ora* CODEDOC API                   │
│  Gibt JSON-Struktur für beliebige Pakete zurück            │
└─────────────────────────────────────────────────────────────┘
```

## Datenschicht

### View: v_ocd_packages

```sql
CREATE OR REPLACE VIEW v_ocd_packages AS
SELECT 
  object_name,
  ocd.api.information(object_name) as pkg_data
FROM user_objects 
WHERE object_type = 'PACKAGE'
ORDER BY object_name;
```

**Spalten:**
- `object_name` (VARCHAR2) – Paketname
- `pkg_data` (CLOB) – Komplette JSON-Dokumentation

**Zugriff in APEX:**
```sql
-- Alle Pakete
SELECT * FROM v_ocd_packages;

-- Einzelnes Paket
SELECT pkg_data FROM v_ocd_packages 
WHERE object_name = 'MY_PACKAGE';
```

## JSON-Struktur (ocd.api.information Ausgabe)

Beispiel für `SELECT ocd.api.information('MY_PACKAGE') FROM DUAL;`:

```json
{
  "name": "MY_PACKAGE",
  "description": "Package description",
  "status": "VALID",
  "functions": [
    {
      "name": "CALC_VALUE",
      "description": "Calculates something",
      "return_type": "NUMBER",
      "parameters": [
        {
          "name": "p_input",
          "type": "VARCHAR2",
          "mode": "IN",
          "description": "Input parameter"
        }
      ]
    }
  ],
  "procedures": [
    {
      "name": "DO_SOMETHING",
      "description": "Performs an action",
      "parameters": [...]
    }
  ],
  "subtypes": [...],
  "constants": [...]
}
```

## Page Flow

```
┌──────────────────┐
│   P1: Home       │  - IR mit v_ocd_packages
│   (List)         │  - Suchfeld P1_SEARCH
└────────┬─────────┘
         │ (Hyperlink)
         │ P2_PACKAGE_NAME = :PACKAGE_NAME
         ↓
┌──────────────────┐
│   P2: Details    │  - Statische Regions
│  (Funktionen,    │  - JSON-Parsing via JSON_TABLE
│   Prozeduren)    │  - Accordion/IR für Details
└────────┬─────────┘
         │ (Fehler)
         ↓
┌──────────────────┐
│   P3: Error      │  - Simple Fehlerseite
│                  │  - Link zurück zu P1
└──────────────────┘
```

## APEX Pages – Details

### Page P1: Package List

**Region: Packages (Interactive Report)**
- Source: `SELECT * FROM v_ocd_packages`
- Columns:
  - `OBJECT_NAME` – Hyperlink zu P2 (Parameter: `P2_PACKAGE_NAME`)
  - `PKG_DATA` → JSON_VALUE() für Description & Status in Report Columns
  
**Items:**
- `P1_SEARCH` – Text Input, Auto-Submit
- Dynamic Action: `P1_SEARCH changed` → Filter IR

**Process:**
- `P1_FILTER` – Dynamic Action auf IR Query mit WHERE-Clause

### Page P2: Package Details

**Item:**
- `P2_PACKAGE_NAME` – Hidden, kommt von P1 Parameter

**Region 1: Package Overview (Static Content)**
```sql
SELECT 
  json_value(pkg_data, '$.name') as name,
  json_value(pkg_data, '$.description') as description,
  json_value(pkg_data, '$.status') as status
FROM v_ocd_packages
WHERE object_name = :P2_PACKAGE_NAME
```

**Region 2: Functions (Interactive Report)**
```sql
SELECT 
  json_value(func, '$.name') as func_name,
  json_value(func, '$.description') as func_desc,
  json_value(func, '$.return_type') as return_type
FROM v_ocd_packages,
  JSON_TABLE(pkg_data, '$.functions[*]' COLUMNS (func PATH '$'))
WHERE object_name = :P2_PACKAGE_NAME
ORDER BY func_name
```

**Region 3: Procedures (Interactive Report)**
- Analog zu Functions, aber aus `$.procedures[*]`

**Region 4: JSON Source (Optional, Static Content)**
```sql
SELECT pkg_data FROM v_ocd_packages 
WHERE object_name = :P2_PACKAGE_NAME
```
Mit HTML `<pre>` und Format-Button.

### Page P3: Error Page

Einfache Static Region mit Text:
```
"Package '%P2_PACKAGE_NAME%' not found or not documented."
Link back to P1
```

## Grants (falls nötig)

Da alles im OCD Schema läuft und APEX auch dort installiert wird, sind keine zusätzlichen Grants notwendig. Falls APEX aber in einem separaten Schema läuft:

```sql
-- Im OCD Schema:
GRANT SELECT ON v_ocd_packages TO <APEX_SCHEMA>;
GRANT EXECUTE ON api TO <APEX_SCHEMA>;
```

## Performance-Überlegungen

**Current (MVP):**
- Jede Anfrage ruft `ocd.api.information()` auf
- OK für kleine bis mittlere Paketmengen
- ~100ms pro Anfrage (abhängig von Package-Größe)

**Future Optimization:**
- Materialized View mit nächtlichem Refresh
- JSON-Caching in Tabelle
- ggf. REST-API mit HTTP-Caching
