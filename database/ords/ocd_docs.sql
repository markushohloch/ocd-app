-- ORDS REST-Modul ocd.docs
-- Stellt die Dokumentation aus ora* CODEDOC per REST bereit, unabhaengig von den APEX-Apps.
-- Ausfuehren im OCD Schema; das Schema muss fuer ORDS aktiviert sein (ords.enable_schema).
--
--   GET .../ords/<schema-alias>/docs/packages/        Liste aller Packages (schema, name, desc)
--   GET .../ords/<schema-alias>/docs/packages/:name   JSON aus ocd.api.information, 404 falls unbekannt;
--                                                     ?schema=<name> waehlt das Schema, Standard ist OCD
--
-- Es gelten die Schemas aus ocd_apex_schema.
--
-- Die Endpunkte sind oeffentlich lesbar.

BEGIN
  ords.define_module(
    p_module_name    => 'ocd.docs',
    p_base_path      => '/docs/',
    p_items_per_page => 25,
    p_status         => 'PUBLISHED',
    p_comments       => 'Documentation of PL/SQL packages created by ora* CODEDOC');

  ords.define_template(
    p_module_name => 'ocd.docs',
    p_pattern     => 'packages/',
    p_comments    => 'All packages of the selected schemas');

  ords.define_handler(
    p_module_name    => 'ocd.docs',
    p_pattern        => 'packages/',
    p_method         => 'GET',
    p_source_type    => ords.source_type_collection_feed,
    p_items_per_page => 25,
    p_source         => q'[
select schema_name                    as schema,
       object_name                    as name,
       json_value(pkg_data, '$.desc') as "desc"
  from ocd_apex_package_docs
 order by schema_name, object_name]');

  ords.define_template(
    p_module_name => 'ocd.docs',
    p_pattern     => 'packages/:name',
    p_comments    => 'Documentation of a single package');

  ords.define_handler(
    p_module_name => 'ocd.docs',
    p_pattern     => 'packages/:name',
    p_method      => 'GET',
    p_source_type => ords.source_type_plsql,
    p_source      => q'[
declare
  v_schema varchar2(128) := upper(nvl(:schema, user));
  v_json   clob;
  v_offset pls_integer := 1;
begin
  if not ocd_apex_util.is_package(:name, v_schema) then
    :status_code := 404;
    return;
  end if;

  v_json := ocd.api.information(upper(:name), v_schema);

  owa_util.mime_header('application/json', true, 'UTF-8');
  while v_offset <= dbms_lob.getlength(v_json) loop
    htp.prn(dbms_lob.substr(v_json, 8000, v_offset));
    v_offset := v_offset + 8000;
  end loop;
end;]');

  COMMIT;
END;
/
