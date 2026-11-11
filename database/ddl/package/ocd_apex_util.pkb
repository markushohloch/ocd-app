-- Package Body: ocd_apex_util

CREATE OR REPLACE PACKAGE BODY ocd_apex_util AS

  -- Page of the APEX application that shows a single package.
  c_details_page CONSTANT PLS_INTEGER := 2;

  -- One entry of `$.components[*]` from [[API.INFORMATION]].
  -- @Position of the component within the package specification.
  -- @Name of the component.
  -- @One of `FUNCTION`, `PROCEDURE`, `CONSTANT`, `SUBTYPE`, `TYPE` or `EXCEPTION`.
  -- @Description of the component.
  -- @Declaration of a function or procedure.
  -- @Data type of a constant.
  -- @Value of a constant.
  -- @Parameters of a function or procedure as JSON array.
  -- @Code examples of a function or procedure as JSON array.
  -- @Fields of a record type as JSON array.
  -- @Number of the overload, starting with 1.
  -- @Number of components with the same name.
  TYPE t_component IS RECORD (
    comp_seq    PLS_INTEGER,
    comp_name   VARCHAR2(128),
    comp_type   VARCHAR2(30),
    comp_desc   VARCHAR2(4000),
    syntax      VARCHAR2(4000),
    datatype    VARCHAR2(4000),
    const_value VARCHAR2(4000),
    parameters  CLOB,
    examples    CLOB,
    fields      CLOB,
    overload    PLS_INTEGER,
    name_count  PLS_INTEGER
  );
  -- All components of a package in declaration order.
  TYPE t_component_tab IS TABLE OF t_component;


  FUNCTION package_names(i_schema_name IN VARCHAR2) RETURN sys.odcivarchar2list IS
    -- Comma separated, with a trailing comma; NULL if there is no package.
    -- The source code is read from the dictionary by the role of OCD.WORKER.
    v_list  CLOB := ocd.worker.schema_packages(UPPER(i_schema_name));
    v_names sys.odcivarchar2list := sys.odcivarchar2list();

  BEGIN
    FOR i IN 1 .. NVL(REGEXP_COUNT(v_list, '[^,]+'), 0) LOOP
      v_names.EXTEND;
      v_names(i) := REGEXP_SUBSTR(v_list, '[^,]+', 1, i);
    END LOOP;

    RETURN v_names;

  END package_names;


  FUNCTION is_package(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN BOOLEAN IS
    v_count PLS_INTEGER;

  BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM ocd_apex_schema s,
         TABLE(package_names(s.schema_name)) p
    WHERE s.schema_name  = UPPER(i_schema_name)
      AND p.column_value = UPPER(i_package_name);

    RETURN v_count > 0;

  END is_package;


  PROCEDURE inspect_all_packages IS
    v_count PLS_INTEGER := 0;
    v_errors PLS_INTEGER := 0;

    CURSOR c_packages IS
      SELECT s.schema_name, p.column_value AS package_name
      FROM ocd_apex_schema s,
           TABLE(package_names(s.schema_name)) p
      ORDER BY s.schema_name, p.column_value;

  BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting documentation of all packages...');
    DBMS_OUTPUT.PUT_LINE('=============================================');

    FOR r_pkg IN c_packages LOOP
      BEGIN
        -- Inspect the package specification with ocd.api
        ocd.api.inspect(
          i_package_code => ocd.worker.object_code(r_pkg.schema_name, r_pkg.package_name),
          i_package_name => r_pkg.package_name,
          i_schema_name  => r_pkg.schema_name
        );

        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE('✓ Documented: ' || r_pkg.schema_name || '.' || r_pkg.package_name);

      EXCEPTION WHEN OTHERS THEN
        v_errors := v_errors + 1;
        DBMS_OUTPUT.PUT_LINE('✗ Error for ' || r_pkg.schema_name || '.' || r_pkg.package_name || ': ' || SQLERRM);
      END;

    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('Completed: ' || v_count || ' packages documented');
    IF v_errors > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Errors: ' || v_errors);
    END IF;
    
  END inspect_all_packages;

  
  PROCEDURE inspect_package(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) IS
    v_package_name VARCHAR2(128) := UPPER(i_package_name);
    v_schema_name  VARCHAR2(128) := UPPER(i_schema_name);

  BEGIN
    IF NOT is_package(v_package_name, v_schema_name) THEN
      RAISE_APPLICATION_ERROR(
        -20001,
        'Package ' || v_schema_name || '.' || v_package_name
          || ' not found in the schemas of OCD_APEX_SCHEMA'
      );
    END IF;

    -- Inspect the package specification with ocd.api
    ocd.api.inspect(
      i_package_code => ocd.worker.object_code(v_schema_name, v_package_name),
      i_package_name => v_package_name,
      i_schema_name  => v_schema_name
    );

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('✓ Package ' || v_schema_name || '.' || v_package_name || ' documented successfully');

  END inspect_package;

  
  FUNCTION get_documented_count RETURN PLS_INTEGER IS
    v_count PLS_INTEGER;

  BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM ocd_apex_package_docs
    WHERE json_value(pkg_data, '$.desc') IS NOT NULL;

    RETURN v_count;

  END get_documented_count;


  FUNCTION params_md(
    i_object_name IN VARCHAR2,
    i_comp_name   IN VARCHAR2,
    i_schema_name IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB IS
    v_result CLOB;
    v_line   VARCHAR2(4200);

  BEGIN
    FOR r_param IN (
      SELECT param_name, param_desc
      FROM ocd_apex_component_params
      WHERE schema_name = UPPER(i_schema_name)
        AND object_name = i_object_name
        AND comp_name   = i_comp_name
      ORDER BY param_seq
    ) LOOP
      v_line := '* ' || r_param.param_name;

      IF r_param.param_desc IS NOT NULL THEN
        v_line := v_line || ': ' || r_param.param_desc;
      END IF;

      IF v_result IS NULL THEN
        v_result := v_line;
      ELSE
        v_result := v_result || CHR(10) || v_line;
      END IF;

    END LOOP;

    RETURN v_result;

  END params_md;


  -- Private function.
  -- Builds the HTML id of a component, e.g. `ocd-inspect` or `ocd-inspect-2`.
  --
  -- The id is used as anchor in [[PACKAGE_HTML]] and as link target in
  -- [[TEXT_HTML]]. The return value is already escaped for an HTML attribute,
  -- because quoted identifiers like `"C_>>"` may contain any character.
  -- @The name of the component.
  -- @The number of the overload; only overloads after the first get a suffix.
  FUNCTION anchor_id(
    i_comp_name IN VARCHAR2,
    i_overload  IN PLS_INTEGER DEFAULT 1
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN apex_escape.html_attribute(
      'ocd-' || LOWER(i_comp_name)
      || CASE WHEN i_overload > 1 THEN '-' || i_overload END);
  END anchor_id;


  -- Private function.
  -- Builds the URL of the details page for a package.
  -- The return value contains the checksum required by the page, as long as
  -- it is called within an APEX session.
  -- @The name of the package, case is ignored.
  -- @The name of the schema, case is ignored.
  FUNCTION package_url(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2
  ) RETURN VARCHAR2 IS
  BEGIN
    RETURN apex_page.get_url(
      p_page   => c_details_page,
      p_items  => 'P2_SCHEMA_NAME,P2_PACKAGE_NAME',
      p_values => UPPER(i_schema_name) || ',' || UPPER(i_package_name));
  END package_url;


  -- Private function.
  -- Resolves the content of a `[[...]]` reference into an HTML link.
  --
  -- Supported forms are `PACKAGE`, `COMPONENT`, `PACKAGE.COMPONENT`,
  -- `SCHEMA.PACKAGE` and `SCHEMA.PACKAGE.COMPONENT`. A single name is taken
  -- as package if such a package exists in the current schema, otherwise as
  -- component of the current package. Two names are taken as package and
  -- component if the first one is a package of the current schema, otherwise
  -- as schema and package. References to the current package link to the
  -- anchor on the same page.
  -- The return value is a `code` element if the package is not shown by the
  -- application, see [[IS_PACKAGE]].
  -- @The reference without the square brackets.
  -- @The package of the text that contains the reference.
  -- @The schema of the text that contains the reference.
  FUNCTION reference_html(
    i_ref          IN VARCHAR2,
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_parts   PLS_INTEGER := REGEXP_COUNT(i_ref, '[^.]+');
    v_part1   VARCHAR2(128) := UPPER(REGEXP_SUBSTR(i_ref, '[^.]+', 1, 1));
    v_part2   VARCHAR2(128) := UPPER(REGEXP_SUBSTR(i_ref, '[^.]+', 1, 2));
    v_part3   VARCHAR2(128) := UPPER(REGEXP_SUBSTR(i_ref, '[^.]+', 1, 3));
    v_schema  VARCHAR2(128) := UPPER(i_schema_name);
    v_package VARCHAR2(128);
    v_comp    VARCHAR2(128);
    v_url     VARCHAR2(4000);

  BEGIN
    IF v_parts = 3 THEN
      v_schema  := v_part1;
      v_package := v_part2;
      v_comp    := v_part3;
    ELSIF v_parts = 2 AND is_package(v_part1, v_schema) THEN
      v_package := v_part1;
      v_comp    := v_part2;
    ELSIF v_parts = 2 THEN
      v_schema  := v_part1;
      v_package := v_part2;
    ELSIF is_package(v_part1, v_schema) THEN
      v_package := v_part1;
    ELSE
      v_package := UPPER(i_package_name);
      v_comp    := v_part1;
    END IF;

    IF v_package IS NULL OR NOT is_package(v_package, v_schema) THEN
      RETURN '<code>' || i_ref || '</code>';
    END IF;

    IF v_comp IS NULL THEN
      v_url := package_url(v_package, v_schema);
    ELSIF v_package = UPPER(i_package_name) AND v_schema = UPPER(i_schema_name) THEN
      v_url := '#' || anchor_id(v_comp);
    ELSE
      v_url := package_url(v_package, v_schema) || '#' || anchor_id(v_comp);
    END IF;

    RETURN '<a href="' || v_url || '">' || i_ref || '</a>';

  END reference_html;


  FUNCTION text_html(
    i_text         IN CLOB,
    i_package_name IN VARCHAR2 DEFAULT NULL,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB IS
    c_ref_pattern CONSTANT VARCHAR2(50) := '\[\[([A-Za-z0-9_$#.]+)\]\]';
    v_html  CLOB;
    v_start PLS_INTEGER;
    v_end   PLS_INTEGER;

  BEGIN
    IF i_text IS NULL THEN
      RETURN NULL;
    END IF;

    -- The escaped slash would break URIs; it is harmless in text content.
    v_html := REPLACE(apex_escape.html(i_text), '&#x2F;', '/');

    -- `code`, its content is masked so that URIs and references stay literal
    LOOP
      v_start := REGEXP_INSTR(v_html, '`[^`]+`', 1, 1, 0);
      EXIT WHEN v_start = 0;
      v_end := REGEXP_INSTR(v_html, '`[^`]+`', 1, 1, 1);
      v_html := SUBSTR(v_html, 1, v_start - 1)
        || '<code>'
        || REPLACE(REPLACE(SUBSTR(v_html, v_start + 1, v_end - v_start - 2), '[', '&#91;'), ':', '&#58;')
        || '</code>'
        || SUBSTR(v_html, v_end);
    END LOOP;

    -- https://example.com/[Name] and plain https://example.com/
    v_html := REGEXP_REPLACE(v_html,
      '(https?://[^[:space:]<[]+)\[([^]]+)\]',
      '<a href="\1" target="_blank" rel="noopener">\2</a>');
    v_html := REGEXP_REPLACE(v_html,
      '(^|[[:space:](])(https?://[^[:space:]<]*[^[:space:]<.,;:!?)])',
      '\1<a href="\2" target="_blank" rel="noopener">\2</a>');

    -- [[PACKAGE.COMPONENT]]
    LOOP
      v_start := REGEXP_INSTR(v_html, c_ref_pattern, 1, 1, 0);
      EXIT WHEN v_start = 0;
      v_end := REGEXP_INSTR(v_html, c_ref_pattern, 1, 1, 1);
      v_html := SUBSTR(v_html, 1, v_start - 1)
        || reference_html(REGEXP_SUBSTR(v_html, c_ref_pattern, 1, 1, NULL, 1), i_package_name, i_schema_name)
        || SUBSTR(v_html, v_end);
    END LOOP;

    -- Lines are already joined by OCD, remaining line breaks separate paragraphs.
    v_html := REGEXP_REPLACE(v_html, '[[:space:]]*' || CHR(10) || '[[:space:]]*', '</p><p>');

    RETURN '<p>' || v_html || '</p>';

  END text_html;


  FUNCTION package_html(
    i_package_name IN VARCHAR2,
    i_schema_name  IN VARCHAR2 DEFAULT USER
  ) RETURN CLOB IS
    v_package_name VARCHAR2(128) := UPPER(i_package_name);
    v_schema_name  VARCHAR2(128) := UPPER(i_schema_name);
    v_json         CLOB;
    v_html         CLOB;
    v_comps        t_component_tab;
    v_started      BOOLEAN;

    -- Private procedure of `package_html`.
    -- Appends a line to the HTML output.
    -- @The HTML fragment.
    PROCEDURE add(i_text IN CLOB) IS
    BEGIN
      v_html := v_html || i_text || CHR(10);
    END add;

    -- Private function of `package_html`.
    -- Renders a code block with a title and a copy button in its header bar.
    -- The copy button is handled by the JavaScript of the details page.
    -- @The code, it is escaped.
    -- @The title, e.g. `Syntax` or `Example 2`; it is not escaped.
    FUNCTION code_html(i_code IN CLOB, i_title IN VARCHAR2) RETURN CLOB IS
    BEGIN
      RETURN '<div class="ocd-code"><div class="ocd-code-bar">'
        || '<h3 class="ocd-code-title">' || i_title || '</h3>'
        || '<button type="button" class="ocd-copy" aria-label="Copy Code">'
        || '<span class="fa fa-copy" aria-hidden="true"></span><span class="ocd-copy-label">Copy</span>'
        || '</button></div>'
        || '<pre><code>' || apex_escape.html(i_code) || '</code></pre></div>';
    END code_html;

    -- Private procedure of `package_html`.
    -- Starts a section with a heading and a table, but only for the first
    -- component of a kind; `v_started` must be reset before each kind.
    -- @The heading of the section.
    -- @The header cells of the table.
    -- @The CSS class of the table, which defines the column widths.
    PROCEDURE start_table(
      i_title  IN VARCHAR2,
      i_header IN VARCHAR2,
      i_class  IN VARCHAR2 DEFAULT 'ocd-name-desc'
    ) IS
    BEGIN
      IF NOT v_started THEN
        add('<h2>' || i_title || '</h2>');
        add('<table class="' || i_class || '"><tr>' || i_header || '</tr>');
        v_started := TRUE;
      END IF;
    END start_table;

    -- Private procedure of `package_html`.
    -- Closes the table opened by `start_table`, if there is one.
    PROCEDURE end_table IS
    BEGIN
      IF v_started THEN
        add('</table>');
      END IF;
    END end_table;

    -- Private procedure of `package_html`.
    -- Renders a JSON array of `{name, desc}` objects as a two column table.
    -- Nothing is rendered if the array is `NULL`.
    -- @The JSON array, e.g. the parameters or fields of a component.
    -- @The header of the first column.
    PROCEDURE name_desc_table(i_json IN CLOB, i_header IN VARCHAR2) IS
    BEGIN
      IF i_json IS NULL THEN
        RETURN;
      END IF;

      add('<table class="ocd-name-desc"><tr><th>' || i_header || '</th><th>Description</th></tr>');
      FOR r_row IN (
        SELECT jt.name, jt.descr
        FROM JSON_TABLE(i_json, '$[*]'
               COLUMNS (
                 seq   FOR ORDINALITY,
                 name  VARCHAR2(128)  PATH '$.name',
                 descr VARCHAR2(4000) PATH '$.desc'
               )) jt
        ORDER BY jt.seq
      ) LOOP
        add('<tr><td><code>' || apex_escape.html(r_row.name) || '</code></td><td>'
          || text_html(r_row.descr, v_package_name, v_schema_name) || '</td></tr>');
      END LOOP;
      add('</table>');
    END name_desc_table;

  BEGIN
    BEGIN
      SELECT pkg_data
      INTO v_json
      FROM ocd_apex_package_docs
      WHERE schema_name = v_schema_name
        AND object_name = v_package_name;
    EXCEPTION WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    END;

    IF json_value(v_json, '$.status') = 'NO_DATA_FOUND' THEN
      RETURN '<p>The package ' || apex_escape.html(v_schema_name || '.' || v_package_name)
        || ' has not been inspected by ora* CODEDOC yet.</p>';
    END IF;

    SELECT jt.comp_seq, jt.comp_name, jt.comp_type, jt.comp_desc,
           jt.syntax, jt.datatype, jt.const_value,
           jt.parameters, jt.examples, jt.fields,
           ROW_NUMBER() OVER (PARTITION BY jt.comp_name ORDER BY jt.comp_seq),
           COUNT(*) OVER (PARTITION BY jt.comp_name)
    BULK COLLECT INTO v_comps
    FROM JSON_TABLE(v_json, '$.components[*]'
           COLUMNS (
             comp_seq    FOR ORDINALITY,
             comp_name   VARCHAR2(128)  PATH '$.name',
             comp_type   VARCHAR2(30)   PATH '$.type',
             comp_desc   VARCHAR2(4000) PATH '$.desc',
             syntax      VARCHAR2(4000) PATH '$.syntax',
             datatype    VARCHAR2(4000) PATH '$.datatype',
             const_value VARCHAR2(4000) PATH '$.value',
             parameters  CLOB FORMAT JSON PATH '$.parameters',
             examples    CLOB FORMAT JSON PATH '$.examples',
             fields      CLOB FORMAT JSON PATH '$.fields'
           )) jt
    ORDER BY jt.comp_seq;

    add('<div class="ocd-doc">');
    add(text_html(json_value(v_json, '$.desc' RETURNING CLOB), v_package_name, v_schema_name));

    -- Constants
    v_started := FALSE;
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type = 'CONSTANT' THEN
        start_table('Constants', '<th>Name</th><th>Type</th><th>Value</th><th>Description</th>', 'ocd-constants');
        add('<tr id="' || anchor_id(v_comps(i).comp_name) || '">'
          || '<td><code>' || apex_escape.html(v_comps(i).comp_name) || '</code></td>'
          || '<td><code>' || apex_escape.html(v_comps(i).datatype) || '</code></td>'
          || '<td><code>' || apex_escape.html(v_comps(i).const_value) || '</code></td>'
          || '<td>' || text_html(v_comps(i).comp_desc, v_package_name, v_schema_name) || '</td></tr>');
      END IF;
    END LOOP;
    end_table;

    -- Subtypes
    v_started := FALSE;
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type = 'SUBTYPE' THEN
        start_table('Subtypes', '<th>Name</th><th>Description</th>');
        add('<tr id="' || anchor_id(v_comps(i).comp_name) || '">'
          || '<td><code>' || apex_escape.html(v_comps(i).comp_name) || '</code></td>'
          || '<td>' || text_html(v_comps(i).comp_desc, v_package_name, v_schema_name) || '</td></tr>');
      END IF;
    END LOOP;
    end_table;

    -- Types, each with its record fields
    v_started := FALSE;
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type = 'TYPE' THEN
        IF NOT v_started THEN
          add('<h2>Types</h2>');
          v_started := TRUE;
        END IF;
        add('<h3 id="' || anchor_id(v_comps(i).comp_name) || '">'
          || apex_escape.html(v_comps(i).comp_name) || '</h3>');
        add(text_html(v_comps(i).comp_desc, v_package_name, v_schema_name));
        name_desc_table(v_comps(i).fields, 'Field');
      END IF;
    END LOOP;

    -- Exceptions
    v_started := FALSE;
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type = 'EXCEPTION' THEN
        start_table('Exceptions', '<th>Name</th><th>Description</th>');
        add('<tr id="' || anchor_id(v_comps(i).comp_name) || '">'
          || '<td><code>' || apex_escape.html(v_comps(i).comp_name) || '</code></td>'
          || '<td>' || text_html(v_comps(i).comp_desc, v_package_name, v_schema_name) || '</td></tr>');
      END IF;
    END LOOP;
    end_table;

    -- Summary of subprograms
    v_started := FALSE;
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type IN ('FUNCTION', 'PROCEDURE') THEN
        start_table('Summary of Subprograms', '<th>Subprogram</th><th>Description</th>');
        add('<tr><td><a href="#' || anchor_id(v_comps(i).comp_name, v_comps(i).overload) || '">'
          || apex_escape.html(v_comps(i).comp_name) || ' ' || INITCAP(v_comps(i).comp_type)
          || CASE WHEN v_comps(i).name_count > 1 THEN ' (' || v_comps(i).overload || ')' END
          || '</a></td><td>' || text_html(v_comps(i).comp_desc, v_package_name, v_schema_name) || '</td></tr>');
      END IF;
    END LOOP;
    end_table;

    -- One section per subprogram
    FOR i IN 1 .. v_comps.COUNT LOOP
      IF v_comps(i).comp_type IN ('FUNCTION', 'PROCEDURE') THEN
        add('<h2 id="' || anchor_id(v_comps(i).comp_name, v_comps(i).overload) || '">'
          || apex_escape.html(v_comps(i).comp_name) || ' ' || INITCAP(v_comps(i).comp_type)
          || CASE WHEN v_comps(i).name_count > 1 THEN ' (' || v_comps(i).overload || ')' END
          || '</h2>');
        add(text_html(v_comps(i).comp_desc, v_package_name, v_schema_name));

        IF v_comps(i).syntax IS NOT NULL THEN
          add(code_html(v_comps(i).syntax, 'Syntax'));
        END IF;

        IF v_comps(i).parameters IS NOT NULL THEN
          add('<h3>Parameters</h3>');
          name_desc_table(v_comps(i).parameters, 'Parameter');
        END IF;

        IF v_comps(i).examples IS NOT NULL THEN
          FOR r_example IN (
            SELECT jt.seq, jt.code, COUNT(*) OVER () AS example_count
            FROM JSON_TABLE(v_comps(i).examples, '$[*]'
                   COLUMNS (
                     seq  FOR ORDINALITY,
                     code CLOB PATH '$.code'
                   )) jt
            ORDER BY jt.seq
          ) LOOP
            add(code_html(r_example.code, 'Example'
              || CASE WHEN r_example.example_count > 1 THEN ' ' || r_example.seq END));
          END LOOP;
        END IF;
      END IF;
    END LOOP;

    add('</div>');

    RETURN v_html;

  END package_html;

END ocd_apex_util;
/
