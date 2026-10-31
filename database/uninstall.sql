-- ocd-apex Database Uninstall
-- Entfernt alle erstellten Objekte

SET ECHO ON;

PROMPT Removing ocd-apex database objects...

-- Package
DROP PACKAGE IF EXISTS ocd_apex_util;

-- Views (abhaengige zuerst)
DROP VIEW IF EXISTS ocd_apex_component_params;
DROP VIEW IF EXISTS ocd_apex_components;
DROP VIEW IF EXISTS ocd_apex_package_docs;

COMMIT;

PROMPT ocd-apex database objects removed successfully!
