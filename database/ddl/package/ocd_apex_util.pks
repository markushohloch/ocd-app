CREATE OR REPLACE PACKAGE ocd_apex_util
-- Utilities for the `ocd-apex` application.
--
-- Wraps [[API]] for bulk documentation and renders documentation
-- fragments for display in APEX pages.
AS

  -- Inspects all VALID packages of the current schema with [[API]].
  -- Useful for documenting a schema in one go.
  -- ^begin
  -- ^  ocd_apex_util.inspect_all_packages;
  -- ^end;
  PROCEDURE inspect_all_packages;

  -- Inspects a single package with [[API]].
  -- Raises `ORA-20001` if the package does not exist in the current schema.
  -- @The name of the package, case is ignored.
  -- ^begin
  -- ^  ocd_apex_util.inspect_package('WORKER');
  -- ^end;
  PROCEDURE inspect_package(i_package_name IN VARCHAR2);

  -- Counts the packages that carry a package level description.
  -- The return value is the number of documented packages.
  -- ^select ocd_apex_util.get_documented_count from dual;
  FUNCTION get_documented_count RETURN PLS_INTEGER;

  -- Renders the parameters of a component as a markdown list.
  --
  -- Each parameter becomes one line of the form `* name: description`;
  -- parameters without a description are rendered as `* name`.
  -- The return value is `NULL` when the component has no parameters.
  -- @The name of the package holding the component.
  -- @The name of the function or procedure.
  -- ^select ocd_apex_util.params_md('API', 'INFORMATION') from dual;
  FUNCTION params_md(
    i_object_name IN VARCHAR2,
    i_comp_name   IN VARCHAR2
  ) RETURN CLOB;

END ocd_apex_util;
/
