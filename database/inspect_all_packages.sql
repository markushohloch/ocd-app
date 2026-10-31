-- Dokumentiere alle bestehenden Packages mit ocd.api.inspect
-- Führe das im OCD Schema aus

DECLARE
  v_package_code CLOB;
  v_package_name VARCHAR2(128);
  v_count PLS_INTEGER := 0;
  
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
      -- Hole Package-Spec DDL
      v_package_code := dbms_metadata.get_ddl('PACKAGE_SPEC', v_package_name);
      
      -- Inspiziere mit ocd.api
      ocd.api.inspect(
        i_package_code => v_package_code,
        i_package_name => v_package_name
      );
      
      v_count := v_count + 1;
      DBMS_OUTPUT.PUT_LINE('✓ Documented: ' || v_package_name);
      
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('✗ Error for ' || v_package_name || ': ' || SQLERRM);
    END;
    
  END LOOP;
  
  COMMIT;
  
  DBMS_OUTPUT.PUT_LINE('=============================================');
  DBMS_OUTPUT.PUT_LINE('Completed: ' || v_count || ' packages documented');
  
END;
/

-- Verify results
SELECT
  object_name,
  json_value(pkg_data, '$.desc') as description,
  (SELECT COUNT(*) FROM ocd_apex_components c
    WHERE c.object_name = p.object_name) as components
FROM ocd_apex_package_docs p
ORDER BY object_name;
