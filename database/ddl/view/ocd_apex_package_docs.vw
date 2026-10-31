-- View: ocd_apex_package_docs
-- Zeigt alle Pakete mit ihren JSON-Dokumentationen aus ocd.api

CREATE OR REPLACE VIEW ocd_apex_package_docs AS
SELECT
  object_name,
  ocd.api.information(object_name, 'OCD') as pkg_data
FROM user_objects
WHERE object_type = 'PACKAGE'
ORDER BY object_name;

PROMPT View ocd_apex_package_docs created successfully.
