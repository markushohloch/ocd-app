-- View: ocd_apex_components
-- Loest $.components[*] aus der JSON-Dokumentation in Zeilen auf.
-- Eine Zeile je Funktion/Prozedur/Konstante eines Packages.

CREATE OR REPLACE VIEW ocd_apex_components AS
SELECT
  p.schema_name,
  p.object_name,
  jt.comp_seq,
  jt.comp_name,
  jt.comp_type,
  jt.comp_desc,
  jt.syntax
FROM ocd_apex_package_docs p,
     JSON_TABLE(p.pkg_data, '$.components[*]'
       COLUMNS (
         comp_seq  FOR ORDINALITY,
         comp_name VARCHAR2(128)  PATH '$.name',
         comp_type VARCHAR2(30)   PATH '$.type',
         comp_desc VARCHAR2(4000) PATH '$.desc',
         syntax    VARCHAR2(4000) PATH '$.syntax'
       )) jt;

PROMPT View ocd_apex_components created successfully.
