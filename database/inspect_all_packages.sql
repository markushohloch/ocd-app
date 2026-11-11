-- Dokumentiere alle Packages der Schemas aus ocd_apex_schema mit ocd.api.inspect
-- Führe das im OCD Schema aus

SET SERVEROUTPUT ON

BEGIN
  ocd_apex_util.inspect_all_packages;
END;
/

-- Verify results
SELECT
  schema_name,
  object_name,
  json_value(pkg_data, '$.desc') as description,
  (SELECT COUNT(*) FROM ocd_apex_components c
    WHERE c.schema_name = p.schema_name
      AND c.object_name = p.object_name) as components
FROM ocd_apex_package_docs p
ORDER BY schema_name, object_name;
