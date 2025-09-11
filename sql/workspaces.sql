create schema if not exists workspaces;

CREATE TABLE workspaces.workspaces (
	id uuid primary key DEFAULT gen_random_uuid() NOT NULL,
	name text not null,
	email text not null,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT NULL
);

 
CREATE OR REPLACE FUNCTION workspaces.set_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_id uuid;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			return workspaces.add_workspace(user_data);
		end if;
		return workspaces.update_workspace(user_data);		
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set workspace', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.add_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    l_email text;
		l_name text;
		l_id uuid;
		l_entity ssh.AuthEntity;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
		IF (l_email IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'EMAIL_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_name := shared.set_null_if_empty(user_data->>'name');
		IF (l_name IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'NAME_IS_EMPTY', 'status', 400)::text;
		END IF;


    INSERT INTO workspaces.workspaces (
        email,
				name
    )
    VALUES (
        l_email,
				l_name
    )
    RETURNING id
		INTO l_id;
 		
		l_entity := ssh.get_auth_entity(user_data);
		l_entity.id := l_id;		
		l_entity := ssh.add_key(l_entity);

    RETURN json_build_object(
        'id', l_id,
				'name', l_name,
        'password', l_entity.password,
				'status',	200
    );
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.update_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_id uuid;
    l_email text;
    l_name text;
		l_entity ssh.AuthEntity;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
    l_name := shared.set_null_if_empty(user_data->>'name');
		l_entity := ssh.get_auth_entity(user_data);
    PERFORM ssh.check_auth_force(l_entity);
    UPDATE workspaces.workspaces u
    	SET
      	email = COALESCE(l_email, u.email),
        name = COALESCE(l_name, u.name),
				update_time = now()
      WHERE id = l_id
      	RETURNING json_build_object(
        	'id', u.id,
          'password', l_new_password,
          'status', 200
       	) INTO res;

      IF res IS NULL THEN
		  	RAISE EXCEPTION 
    			USING 
						ERRCODE = 'EJSON', 
						DETAIL = json_build_object('code', 'WORKSPACE_NOT_FOUND', 'status', 404)::text;
      END IF;

  	 PERFORM ssh.update_key(l_entity);
     RETURN res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.delete_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_entity ssh.AuthEntity;
		v_detail text;
BEGIN
	l_entity := ssh.get_auth_entity(user_data);
	l_entity.id := ssh.check_auth_force(l_entity);

  DELETE FROM workspaces.workspaces u
  	WHERE id = l_entity.id
    RETURNING json_build_object(
      'id', u.id,
      'status', 200
    ) INTO res;
    IF res IS NULL THEN
			RAISE EXCEPTION 
    		USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'WORKSPACE_NOT_FOUND', 'status', 404)::text;        
    END IF;

		l_entity := ssh.get_auth_entity(user_data);
		PERFORM ssh.delete_key(l_entity);
    RETURN res;

		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set workspace', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


