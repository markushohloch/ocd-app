-- View: ocd_apex_package_docs
-- Zeigt alle Pakete der Schemas aus ocd_apex_schema mit ihren JSON-Dokumentationen aus ocd.api

CREATE OR REPLACE VIEW ocd_apex_package_docs AS
SELECT
  s.schema_name,
  p.column_value as object_name,
  ocd.api.information(p.column_value, s.schema_name) as pkg_data
FROM ocd_apex_schema s,
     TABLE(ocd_apex_util.package_names(s.schema_name)) p
ORDER BY s.schema_name, p.column_value;

PROMPT View ocd_apex_package_docs created successfully.
