-- ocd-apex Database Setup
-- Installiert Views und Hilfsobjekte für die APEX-Applikation
-- Ausführen im OCD Schema

SET ECHO ON;
SET TIMING ON;

PROMPT ============================================================================
PROMPT Installing ocd-apex database objects...
PROMPT ============================================================================

-- ============================================================================
-- Views
-- ============================================================================
@ddl/view/ocd_apex_package_docs.vw
@ddl/view/ocd_apex_components.vw
@ddl/view/ocd_apex_component_params.vw

-- ============================================================================
-- Package: ocd_apex_util
-- ============================================================================
@ddl/package/ocd_apex_util.pks
@ddl/package/ocd_apex_util.pkb

-- ============================================================================
-- Abschluss
-- ============================================================================
COMMIT;
PROMPT
PROMPT ============================================================================
PROMPT Installation completed successfully!
PROMPT ============================================================================
PROMPT
PROMPT Next steps:
PROMPT 1. Verify view: SELECT * FROM ocd_apex_package_docs;
PROMPT 2. Verify components: SELECT * FROM ocd_apex_components;
PROMPT 3. Test ocd.api access: SELECT ocd.api.information('PACKAGE_NAME', 'OCD') FROM DUAL;
PROMPT
