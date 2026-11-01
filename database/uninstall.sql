-- ocd-apex Database Uninstall
-- Entfernt alle erstellten Objekte
-- Ohne DROP ... IF EXISTS, das erst ab Oracle 23ai verfuegbar ist

SET ECHO ON;

PROMPT Removing ocd-apex database objects...

DECLARE
  e_object_not_found EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_object_not_found, -4043);
  e_view_not_found EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_view_not_found, -942);

  PROCEDURE drop_object(i_statement IN VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE i_statement;
    DBMS_OUTPUT.PUT_LINE('Done: ' || i_statement);
  EXCEPTION
    WHEN e_object_not_found OR e_view_not_found THEN
      DBMS_OUTPUT.PUT_LINE('Not found: ' || i_statement);
  END drop_object;

BEGIN
  -- ORDS-Modul (optional installiert ueber ords/ocd_docs.sql)
  FOR r_module IN (SELECT name FROM user_ords_modules WHERE name = 'ocd.docs') LOOP
    ords.delete_module(p_module_name => r_module.name);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Done: ords.delete_module(' || r_module.name || ')');
  END LOOP;

  -- Package
  drop_object('DROP PACKAGE ocd_apex_util');

  -- Views (abhaengige zuerst)
  drop_object('DROP VIEW ocd_apex_component_params');
  drop_object('DROP VIEW ocd_apex_components');
  drop_object('DROP VIEW ocd_apex_package_docs');
END;
/

PROMPT ocd-apex database objects removed successfully!
