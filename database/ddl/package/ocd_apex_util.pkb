-- Package Body: ocd_apex_util

CREATE OR REPLACE PACKAGE BODY ocd_apex_util AS

  PROCEDURE inspect_all_packages IS
    v_package_code CLOB;
    v_package_name VARCHAR2(128);
    v_count PLS_INTEGER := 0;
    v_errors PLS_INTEGER := 0;
    
    CURSOR c_packages IS
      SELECT object_name 
      FROM user_objects 
      WHERE object_type = 'PACKAGE' 
        AND status = 'VALID'
      ORDER BY object_name;
      
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Starting documentation of all packages...');
    DBMS_OUTPUT.PUT_LINE('=============================================');
    
    FOR r_pkg IN c_packages LOOP
      v_package_name := r_pkg.object_name;
      
      BEGIN
        -- Get Package-Spec DDL
        v_package_code := dbms_metadata.get_ddl('PACKAGE_SPEC', v_package_name);
        
        -- Inspect with ocd.api
        ocd.api.inspect(
          i_package_code => v_package_code,
          i_package_name => v_package_name
        );
        
        v_count := v_count + 1;
        DBMS_OUTPUT.PUT_LINE('✓ Documented: ' || v_package_name);
        
      EXCEPTION WHEN OTHERS THEN
        v_errors := v_errors + 1;
        DBMS_OUTPUT.PUT_LINE('✗ Error for ' || v_package_name || ': ' || SQLERRM);
      END;
      
    END LOOP;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('=============================================');
    DBMS_OUTPUT.PUT_LINE('Completed: ' || v_count || ' packages documented');
    IF v_errors > 0 THEN
      DBMS_OUTPUT.PUT_LINE('Errors: ' || v_errors);
    END IF;
    
  END inspect_all_packages;

  
  PROCEDURE inspect_package(i_package_name IN VARCHAR2) IS
    v_package_code CLOB;
    v_exists PLS_INTEGER;
    
  BEGIN
    -- Check if package exists
    SELECT COUNT(*)
    INTO v_exists
    FROM user_objects
    WHERE object_name = UPPER(i_package_name)
      AND object_type = 'PACKAGE';
    
    IF v_exists = 0 THEN
      RAISE_APPLICATION_ERROR(
        -20001,
        'Package ' || i_package_name || ' not found in current schema'
      );
    END IF;
    
    -- Get Package-Spec DDL
    v_package_code := dbms_metadata.get_ddl('PACKAGE_SPEC', UPPER(i_package_name));
    
    -- Inspect with ocd.api
    ocd.api.inspect(
      i_package_code => v_package_code,
      i_package_name => UPPER(i_package_name)
    );
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('✓ Package ' || UPPER(i_package_name) || ' documented successfully');
    
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
    i_comp_name   IN VARCHAR2
  ) RETURN CLOB IS
    v_result CLOB;
    v_line   VARCHAR2(4200);

  BEGIN
    FOR r_param IN (
      SELECT param_name, param_desc
      FROM ocd_apex_component_params
      WHERE object_name = i_object_name
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

END ocd_apex_util;
/
