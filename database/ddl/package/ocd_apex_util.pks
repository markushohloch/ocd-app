CREATE OR REPLACE PACKAGE ocd_apex_util
-- Utilities for the `ocd-apex` application.
--
-- Wraps [[API]] for bulk documentation and renders documentation
-- fragments for display in APEX pages.
-- The application covers the schemas listed in the table `OCD_APEX_SCHEMA`.
AS

  -- Lists the packages of a schema, whatever their status.
  -- The return value is empty if the schema has no packages.
  -- @The name of the schema, case is ignored.
  -- ^select column_value from ocd_apex_util.package_names('OCD');
  FUNCTION package_names(i_schema_name IN VARCHAR2) RETURN sys.odcivarchar2list;

  -- Checks whether a package is shown by the application.
  -- The return value is `TRUE` if the schema is listed in `OCD_APEX_SCHEMA`
  -- and the package exists in it, whatever its status.
  -- @The name of the package, case is ignored.
  -- @The name of the schema, case is ignored.
  FUNCTION is_package(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN BOOLEAN;

  -- Inspects all packages of the schemas in `OCD_APEX_SCHEMA` with [[API]].
  -- Useful for documenting the schemas in one go.
  -- ^begin
  --  ocd_apex_util.inspect_all_packages;
  --end;
  PROCEDURE inspect_all_packages;

  -- Inspects a single package with [[API]].
  -- Raises `ORA-20001` if the package is not shown by the application,
  -- see [[IS_PACKAGE]].
  -- @The name of the package, case is ignored.
  -- @The name of the schema, case is ignored.
  -- ^begin
  --  ocd_apex_util.inspect_package('WORKER');
  --end;
  PROCEDURE inspect_package(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  );

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
  -- @The name of the schema holding the package.
  -- ^select ocd_apex_util.params_md('API', 'INFORMATION') from dual;
  FUNCTION params_md(
    i_object_name IN VARCHAR2,
    i_comp_name   IN VARCHAR2,
    i_schema_name IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB;

  -- Converts a description text written in OCDs into HTML.
  --
  -- The text is escaped first. Then backticks become `code` elements,
  -- URIs (optionally followed by a short name in square brackets) become
  -- links, references like `[[PACKAGE.COMPONENT]]` become links to the
  -- details page and line breaks separate paragraphs.
  -- References to packages that are not shown by the application are
  -- rendered as `code` elements.
  -- @The description text.
  -- @The package used to resolve references without a package name.
  -- @The schema used to resolve references without a schema name.
  -- ^select ocd_apex_util.text_html('See [[API.INFORMATION]].', 'API') from dual;
  FUNCTION text_html(
    i_text         IN CLOB,
    i_package_name IN VARCHAR2 DEFAULT NULL,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB;

  -- Renders the complete documentation of a package as HTML.
  --
  -- The layout follows the Oracle Database PL/SQL Packages Reference:
  -- description, constants, subtypes, types, exceptions, a summary of
  -- all subprograms and one section per subprogram.
  -- Every component gets an anchor `ocd-<name>` (overloads get `-<n>`).
  -- The return value is `NULL` when the package is not shown by the
  -- application.
  -- @The name of the package, case is ignored.
  -- @The name of the schema, case is ignored.
  -- ^select ocd_apex_util.package_html('API') from dual;
  FUNCTION package_html(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB;

END ocd_apex_util;
/
