create or replace package BODY wim_slack AS
    g_token VARCHAR2(256) ;
    g_slack_invite_url VARCHAR2(256) ;
    g_slack_inactive_url VARCHAR2(256) ;
    g_slack_userlist_url VARCHAR2(256) ;
    g_slack_userinfo_url VARCHAR2(256) ;
    g_scope_prefix VARCHAR2(32) ;
    function invite(email VARCHAR2, first_name VARCHAR2, last_name VARCHAR2, resend VARCHAR2 default 'false') return PLS_INTEGER IS
        l_data  clob;
        l_url varchar2(4000) := g_slack_invite_url ||'?'||'email='||email||'&'||'first_name'||first_name||'&'||'last_name='||last_name||
        '&'||'token='||g_token||'&'||'resend='||resend;
        
        BEGIN
        apex_web_service.g_request_headers.delete;

        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
    
        l_data := apex_web_service.make_rest_request(
            p_url => l_url,
            p_http_method => 'POST',
            p_body => null
        );
        dbms_output.put_line(l_data);
        dbms_output.put_line('apex_web_service.g_status_code: '||apex_web_service.g_status_code);
        return 1;
        EXCEPTION
            WHEN others
                THEN 
                raise;
    end invite;
    
    function deactivate(user_id VARCHAR2) return PLS_INTEGER IS
        l_data  clob;
        l_url varchar2(4000) := g_slack_inactive_url|| '?'||'user='||user_id||
        '&'||'token='||g_token;
        BEGIN
        apex_web_service.g_request_headers.delete;

        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
    
        l_data := apex_web_service.make_rest_request(
            p_url => l_url,
            p_http_method => 'POST',
            p_body => null
        );
                dbms_output.put_line(l_data);

        dbms_output.put_line('apex_web_service.g_status_code: '||apex_web_service.g_status_code);
        return 1;
        EXCEPTION
            WHEN others
                THEN 
                raise;
    end deactivate;
    
    function get_user_info(user_id VARCHAR2) return PLS_INTEGER IS
        n number;
        l_data  CLOB := q'[{"ok":"true","members":[{"id":"U095L2BBR",  "real_name": "Grainne OShea"},{"id":"U095Lkj", "real_name": "Grainne"}]}]';
        l_content varchar2(4000);
        l_url varchar2(4000) := g_slack_userinfo_url ||'?'||'token='||g_token||'&'||'user='||user_id;       
        BEGIN      
        apex_web_service.g_request_headers.delete;
        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
    
        l_data := apex_web_service.make_rest_request(
            p_url => l_url,
            p_http_method => 'GET',
            p_body => null
        );
    
        dbms_output.put_line('apex_web_service.g_status_code: '||apex_web_service.g_status_code);
        
        apex_json.parse(l_data);
        
        APEX_JSON.initialize_clob_output;
        APEX_JSON.open_object(user_id);
        
        FOR user_rec in (SELECT jt.* 
            FROM (select l_data as json from dual),
            JSON_TABLE(json, '$.user'
            COLUMNS (row_number FOR ORDINALITY,
                 id VARCHAR2(10) PATH '$.id',
                 name VARCHAR2(30) PATH '$.name',
                 real_name VARCHAR2(60) PATH '$.profile.real_name',
                 email VARCHAR2(100) PATH '$.profile.email',
                 status VARCHAR2(10) PATH '$.deleted'))
            AS jt WHERE jt.id=upper(user_id))
        loop
            apex_json.write('name', user_rec.name);
            apex_json.write('real_name', user_rec.real_name);
            apex_json.write('email', user_rec.email);
            apex_json.write('status', CASE WHEN user_rec.status='true' THEN 'inactive' ELSE 'active' END);
        end loop;
        
        
        APEX_JSON.close_all;
        dbms_output.put_line(APEX_JSON.get_clob_output);
        return 1;
        
    end get_user_info;
     
    function get_user_id(p_email VARCHAR2) return VARCHAR2 IS
        n number;
        l_user VARCHAR2(20);
        l_data  CLOB := q'[{"ok":"true","members":[{"id":"U095L2BBR",  "real_name": "Grainne OShea"},{"id":"U095Lkj", "real_name": "Grainne"}]}]';
        l_content varchar2(4000);
        l_url varchar2(4000) := g_slack_userlist_url ||'?'||'token='||g_token;
        l_count NUMBER(3) := 0;
        BEGIN      
        apex_web_service.g_request_headers.delete;

        apex_web_service.g_request_headers(1).name := 'Content-Type';
        apex_web_service.g_request_headers(1).value := 'application/json';
    
        l_data := apex_web_service.make_rest_request(
            p_url => l_url,
            p_http_method => 'GET',
            p_body => null
        );
    
        dbms_output.put_line('apex_web_service.g_status_code: '||apex_web_service.g_status_code);
        
        apex_json.parse(l_data);
        
        SELECT jt.id INTO l_user
            FROM (select l_data as json from dual),
            JSON_TABLE(json, '$.members[*]'
            COLUMNS (row_number FOR ORDINALITY,
                 id VARCHAR2(10) PATH '$.id',
                 name VARCHAR2(30) PATH '$.name',
                 real_name VARCHAR2(60) PATH '$.profile.real_name',
                 email VARCHAR2(100) PATH '$.profile.email',
                 status VARCHAR2(10) PATH '$.deleted'))
            AS jt
        where lower(jt.email)=lower(p_email);
        
        return l_user;
        
    end get_user_id; 
     
    BEGIN
        select value into g_token 
            from devldap.wdt_app_settings 
                where section = 'SLACK' and name = 'TOKEN';
        select value into g_slack_inactive_url 
            from devldap.wdt_app_settings 
                where section = 'SLACK' and name = 'DEACTIVATE_URL';
        select value into g_slack_userlist_url 
            from devldap.wdt_app_settings 
                where section = 'SLACK' and name = 'USER_LIST_URL';
        select value into g_slack_userinfo_url 
            from devldap.wdt_app_settings 
                where section = 'SLACK' and name = 'USER_INFO_URL';
        select value into g_slack_invite_url 
            from devldap.wdt_app_settings 
                where section = 'SLACK' and name = 'INVITE_URL';
        g_scope_prefix := lower($$PLSQL_UNIT) || '.'; 
        
        EXCEPTION
        WHEN OTHERS THEN
            logger.log_error(
                p_scope => g_scope_prefix || 'package_initialization');
            raise; 
        
end wim_slack;
/
show error