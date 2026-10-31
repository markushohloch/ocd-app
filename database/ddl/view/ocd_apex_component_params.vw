-- View: ocd_apex_component_params
-- Loest $.components[*].parameters[*] in Zeilen auf.
-- Eine Zeile je Parameter; Komponenten ohne Parameter erscheinen nicht.

CREATE OR REPLACE VIEW ocd_apex_component_params AS
SELECT
  p.object_name,
  jt.comp_name,
  jt.comp_type,
  jt.param_seq,
  jt.param_name,
  jt.param_desc
FROM ocd_apex_package_docs p,
     JSON_TABLE(p.pkg_data, '$.components[*]'
       COLUMNS (
         comp_name VARCHAR2(128) PATH '$.name',
         comp_type VARCHAR2(30)  PATH '$.type',
         NESTED PATH '$.parameters[*]'
           COLUMNS (
             param_seq  FOR ORDINALITY,
             param_name VARCHAR2(128)  PATH '$.name',
             param_desc VARCHAR2(4000) PATH '$.desc'
           )
       )) jt
WHERE jt.param_name IS NOT NULL;

PROMPT View ocd_apex_component_params created successfully.
