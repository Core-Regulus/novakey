CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgsodium;


CREATE TABLE users.users (
	id uuid primary key DEFAULT gen_random_uuid() NOT NULL,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT NULL,
	last_visited timestamptz DEFAULT now() NOT null,	 
	email text not null,
	username text not null
);


create table users.users_workspaces (
	user_id 			uuid references users.users (id) on delete cascade,
	workspace_id 	uuid references workspaces.workspaces (id) on delete cascade,	
	role_code			ltree references roles.roles (code),
	check (role_code <@ 'root.workspace'),
	primary key (user_id, workspace_id)
);

create index on users.users_workspaces using hash (user_id);
create index on users.users_workspaces using hash (workspace_id);

create table if not exists users.users_projects (
	user_id 			uuid references users.users (id) on delete cascade,
	project_id 		uuid references projects.projects (id) on delete cascade,	
	role_code			ltree references roles.roles (code),
	check (role_code <@ 'root.workspace.project'),
	primary key (user_id, project_id)
);

create index on users.users_workspaces using hash (user_id);
create index on users.users_workspaces using hash (workspace_id);

CREATE OR REPLACE FUNCTION users.add_user(user_data jsonb)
RETURNS ssh.EntityResult AS $$
DECLARE 
		l_id uuid;
		l_username text;
    l_email text;
		l_res ssh.EntityResult;
		l_entity ssh.AuthEntity;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
		IF (l_email IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'EMAIL_IS_EMPTY', 'status', 400)::text;
		END IF;
    
    l_username := ssh.get_public_key_username(user_data->>'publicKey');

    INSERT INTO users.users (
        email,
				username
    )
    VALUES (
        l_email,
				l_username
    )
    RETURNING id
		INTO l_id;

		l_res.entity := ssh.get_auth_entity(user_data);
		l_res.entity.id := l_id;
		l_res.entity := ssh.add_key(l_res.entity);
		l_entity := l_res.entity;
		l_res.data := jsonb_build_object(
        'id', l_id,
				'username', l_username,
				'publicKey', user_data->>'publicKey',
        'password', l_entity.password,
				'status',	200
    );
    RETURN l_res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.update_user(user_data jsonb)
RETURNS ssh.EntityResult AS $$
DECLARE 
    l_id uuid;
    l_email text;
		l_res ssh.EntityResult;
		l_entity ssh.AuthEntity;
BEGIN
	l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
  l_email := shared.set_null_if_empty(user_data->>'email');        
	l_res.entity := ssh.get_auth_entity(user_data);
  l_res.entity := ssh.check_auth_force(l_entity);
	l_entity := l_res.entity;
  UPDATE users.users u
  	SET
    	email = COALESCE(l_email, u.email),
      last_visited = now(),
			update_time = now()
    WHERE id = l_id
    	RETURNING jsonb_build_object(
      	'id', u.id,
				'publicKey', user_data->>'publicKey',
        'password', l_new_password,
        'status', 200
      ) INTO l_res.data;

  IF l_res.data IS NULL THEN
    RAISE EXCEPTION
     USING 
			ERRCODE = 'EJSON', 
			DETAIL = jsonb_build_object('code', 'USER_NOT_FOUND', 'status', 404)::text;    
  END IF;

	l_res.entity := ssh.update_key(l_res.entity);
	RETURN res;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION users.set_user(user_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res ssh.EntityResult;
		l_entity ssh.AuthEntity;
		l_id uuid;
		l_signer ssh.AuthEntity;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			res := users.add_user(user_data);
		else 
			res :=  users.update_user(user_data);
		end if;
		l_signer := ssh.get_signer(user_data->'signer', res.entity);
		l_entity := res.entity;
		perform users.set_workspaces(l_entity.id, user_data->'workspaces', l_signer);
		perform users.set_projects(l_entity.id, user_data->'projects', l_signer);
		return res.data;
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set users', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.delete_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_key bytea;
		l_id uuid;
		l_entity ssh.AuthEntity;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;    
		l_entity := ssh.get_auth_entity(user_data);
    l_entity := ssh.check_auth_force(l_entity);
    DELETE FROM users.users u
    	WHERE id = l_entity.id
      RETURNING json_build_object(
      	'id', u.id,
        'status', 200
      ) INTO res;

    IF res IS NULL THEN
    	RAISE EXCEPTION
     		USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'USER_NOT_FOUND', 'status', 404)::text;        
    END IF;
		PERFORM ssh.delete_key(l_entity);	
    RETURN res;
END;
$$ LANGUAGE plpgsql;


create or replace function users.set_workspaces(
    user_id uuid,
    workspace_data jsonb,
    entity ssh.AuthEntity
)
RETURNS void AS $$
DECLARE
    ws jsonb;
BEGIN
    IF jsonb_typeof(workspace_data) != 'array' THEN
        RAISE EXCEPTION 
            USING 
                ERRCODE = 'EJSON',
                DETAIL = jsonb_build_object('code', 'WORKSPACES_NOT_ARRAY', 'status', 400)::text;
    END IF;

    FOR ws IN
        SELECT jsonb_array_elements(workspace_data)
    LOOP
        PERFORM users.set_workspace(user_id, ws, entity);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


create or replace function users.set_workspace(a_user_id uuid, workspace_data jsonb, entity ssh.AuthEntity)
RETURNS void AS $$
DECLARE 		
		l_id uuid;
		l_role_code text;
BEGIN
		l_id := shared.set_null_if_empty(workspace_data->>'id')::uuid;
		IF (l_id IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ID_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_role_code := shared.set_null_if_empty(workspace_data->>'roleCode');
		IF (l_role_code IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ROLE_CODE_IS_EMPTY', 'status', 400)::text;
		END IF;
		
		PERFORM workspaces.check_access_force(entity, l_id);
		insert into users.users_workspaces(user_id, workspace_id, role_code)
		values (a_user_id, l_id, l_role_code::ltree)
		on conflict (user_id, workspace_id) do update
			set role_code = excluded.role_code;
END;
$$ LANGUAGE plpgsql;

create or replace function users.set_projects(
    user_id uuid,
    project_data jsonb,
    entity ssh.AuthEntity
)
RETURNS void AS $$
DECLARE
    ws jsonb;
BEGIN
    IF jsonb_typeof(project_data) != 'array' THEN
        RAISE EXCEPTION 
            USING 
                ERRCODE = 'EJSON',
                DETAIL = jsonb_build_object('code', 'PROJECT_NOT_ARRAY', 'status', 400)::text;
    END IF;

    FOR ws IN
        SELECT jsonb_array_elements(project_data)
    LOOP
        PERFORM users.set_project(user_id, ws, entity);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.set_project(a_user_id uuid, project_data jsonb, entity ssh.AuthEntity)
RETURNS void AS $$
DECLARE 		
		l_id uuid;
		l_role_code text;
BEGIN
		l_id := shared.set_null_if_empty(project_data->>'id')::uuid;
		IF (l_id IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ID_IS_EMPTY', 'status', 400)::text;
		END IF;
    l_role_code := shared.set_null_if_empty(project_data->>'roleCode');
		IF (l_role_code IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ROLE_CODE_IS_EMPTY', 'status', 400)::text;
		END IF;
		PERFORM projects.check_access_force(entity, l_id, ARRAY['root.workspace.project.admin']::ltree[]);
		insert into users.users_projects(user_id, project_id, role_code)
		values (a_user_id, l_id, l_role_code::ltree)
		on conflict (user_id, project_id) do update
			set role_code = excluded.role_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.check_workspace_selectors(a_user_id uuid, a_workspace_id uuid, selectors ltree[])
RETURNS ltree AS $$
declare
	l_res ltree;
BEGIN
	select p.selector_code from users.users_workspaces w
	inner join roles.profiles p on (p.role_code = w.role_code)
	where (w.user_id = a_user_id and w.workspace_id = a_workspace_id and p.selector_code = any(selectors))
	into l_res
	limit 1;
	return l_res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.check_workspace_selectors_force(a_user_id uuid, a_workspace_id uuid, a_selectors ltree[])
RETURNS ltree AS $$
declare
	l_selector ltree;
BEGIN
	l_selector := users.check_workspace_selectors(a_user_id, a_workspace_id, a_selectors);
	if (l_selector is null) then
		raise exception 
	  	using
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'WORKSPACE_NO_ACCESS', 'status', 401)::text;
	end if;
	return l_selector;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.check_project_selectors(a_user_id uuid, a_project_id uuid, selectors ltree[])
RETURNS ltree AS $$
declare
	l_res ltree;
BEGIN
	select p.selector_code from users.users_projects w
	inner join roles.profiles p on (p.role_code = w.role_code)
	where (w.user_id = a_user_id and w.project_id = a_project_id and p.selector_code = any(selectors))
	into l_res
	limit 1;
	return l_res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.check_project_selectors_force(a_user_id uuid, a_project_id uuid, a_selectors ltree[])
RETURNS ltree AS $$
declare
	l_selector ltree;
BEGIN
	l_selector := users.check_project_selectors(a_user_id, a_project_id, a_selectors);
	if (l_selector is null) then
		raise exception 
	  	using
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'PROJECT_NO_ACCESS', 'status', 401)::text;
	end if;
	return l_selector;
END;
$$ LANGUAGE plpgsql;

