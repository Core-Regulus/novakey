create schema if not exists projects;

create table projects.projects(
	id uuid primary key default gen_random_uuid(),
	name text,
	description text,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now()
);


create table projects.keys (
	project_id uuid references projects.projects (id) on delete cascade,
	key text,	
	value text,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now(),
	primary key (project_id, key),
	unique(key, value)
);

create index on projects.keys using hash (project_id);

 



create table projects.project_workspace (
	project_id uuid references projects.projects (id) on delete cascade,
	workspace_id uuid references workspaces.workspaces (id) on delete cascade,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now() 
)


CREATE OR REPLACE FUNCTION projects.set_project(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_id uuid;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			return projects.add_project(user_data);
		end if;
		return projects.update_project(user_data);		
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.add_project(user_data jsonb)
RETURNS json AS $$
DECLARE 
    l_description text;
		l_name text;
		l_id uuid;
		l_workspace_id uuid;
BEGIN
    l_name := shared.set_null_if_empty(user_data->>'name');
		IF (l_name IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'NAME_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_description := shared.set_null_if_empty(user_data->>'description');
		IF (l_description IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'DESCRIPTION_IS_EMPTY', 'status', 400)::text;
		END IF;

   l_workspace_id := shared.set_null_if_empty(user_data->>'workspace_id');
		IF (l_workspace_id IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'WORKSPACE_ID_IS_EMPTY', 'status', 400)::text;
		END IF;

    INSERT INTO projects.projects (
				name,
				description
    )
    VALUES (
        l_name,
				l_description
    )
    RETURNING id
		INTO l_id;

		PERFORM projects.set_workspace(l_id, l_workspace_id);
    RETURN json_build_object(
        'id', l_id,
				'name', l_name,
        'description', l_description,
				'status',	200
    );
	END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projects.set_workspace(project_id uuid, workspace_id uuid)
RETURNS void AS $$
BEGIN
    INSERT INTO projects.project_workspace (
				project_id,
				workspace_id
    )
    VALUES (
        project_id,
				workspace_id
    ) 
		ON CONFLICT DO NOTHING;
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



