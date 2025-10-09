create schema if not exists projects;

drop table projects.projects cascade;

create table projects.projects(
	id uuid primary key default gen_random_uuid(),
	name text not null,
	description text,
	workspace_id uuid not null references workspaces.workspaces on delete cascade,
	owner uuid not null references users.users on delete cascade,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now(),
	unique (workspace_id, name)
);


create index on projects.projects using hash (workspace_id);
create index on projects.projects using hash (owner);

create table if not exists projects.keys (
	project_id uuid references projects.projects (id) on delete cascade,
	key text,	
	value text,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now(),
	primary key (project_id, key, value)
);

create index on projects.keys using hash (project_id);

 
create table if not exists projects.project_workspace (
	project_id uuid references projects.projects (id) on delete cascade,
	workspace_id uuid references workspaces.workspaces (id) on delete cascade,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now() 
)


CREATE OR REPLACE FUNCTION projects.set_project(project_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_id uuid;
		l_signer ssh.AuthEntity;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(project_data->>'id')::uuid;
		l_signer := ssh.check_auth_force(project_data->'signer');
		if (l_id is null) then
			res := projects.add_project(project_data);
		else
			res := projects.update_project(project_data);
		end if;
		
		perform projects.set_keys((res->>'id')::uuid, project_data->'keys', l_signer);
		return res;
			
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.add_project(project_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    l_description text;
		l_name text;
		l_id uuid;
		l_workspace_id uuid;
		l_entity ssh.AuthEntity;
		l_owner_id uuid;
BEGIN
    l_name := shared.set_null_if_empty(project_data->>'name');
		IF (l_name IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'NAME_IS_EMPTY', 'status', 400)::text;
		END IF;

   l_workspace_id := shared.set_null_if_empty(project_data->>'workspaceId');
		IF (l_workspace_id IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'WORKSPACE_ID_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_description := shared.set_null_if_empty(project_data->>'description');		
		l_entity := ssh.check_auth_force(project_data->'signer');		
		
    INSERT INTO projects.projects (
				name,
				workspace_id,
				description,
				owner
    )
    VALUES (
        l_name,
				l_workspace_id,
				l_description,
				l_entity.id
    )
    RETURNING id
		INTO l_id;

    RETURN jsonb_build_object(
        'id', l_id,
				'name', l_name,
        'description', l_description,
				'roleCodes', users.get_user_project_roles(l_id, l_entity.id),
				'status',	200
    );
	END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projects.update_project(project_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
    l_id uuid;
    l_name text;
		l_entity ssh.AuthEntity;
		l_owner uuid;
BEGIN
    l_id := shared.set_null_if_empty(project_data->>'id');
    l_name := shared.set_null_if_empty(project_data->>'name');

		l_entity := ssh.get_auth_entity(project_data->'user');
		l_owner := shared.set_null_if_empty(project_data->>'newOwner');
		PERFORM projects.check_access_force(l_entity, l_id, ARRAY['root.workspace.project.write']::tree[]);

    UPDATE projects.projects p
    	SET
        name = COALESCE(l_name, p.name),
        description = COALESCE(l_description, p.description),
				owner = COALESCE(l_owner, p.owner),
				update_time = now()
      WHERE id = l_id
      	RETURNING jsonb_build_object(
        	'id', p.id,
					'name', p.name,
  	      'description', p.description,
					'roleCodes', users.get_user_project_roles(p.id, p.owner),
          'status', 200
       	) INTO res;

      IF res IS NULL THEN
		  	RAISE EXCEPTION 
    			USING 
						ERRCODE = 'EJSON', 
						DETAIL = jsonb_build_object('code', 'PROJECT_NOT_FOUND', 'status', 404)::text;
      END IF;

     RETURN res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.delete_project(project_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_entity ssh.AuthEntity;
		l_id uuid;
		v_detail text;
BEGIN
  l_id := shared.set_null_if_empty(project_data->>'id');
	l_entity := ssh.get_auth_entity(project_data->'signer');
	PERFORM projects.check_access_force(l_entity, l_id, ARRAY['root.workspace.project.admin']::ltree[]);

  DELETE FROM projects.projects p
  	WHERE id = l_id
    RETURNING jsonb_build_object(
      'id', p.id,
      'status', 200
    ) INTO res;
    IF res IS NULL THEN
			RAISE EXCEPTION 
    		USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'PROJECT_NOT_FOUND', 'status', 404)::text;        
    END IF;
    RETURN res;

		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t delete project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projects.check_access_force(entity ssh.AuthEntity, project_id uuid, a_selectors ltree[])
RETURNS void AS $$
DECLARE
	l_res uuid;
	l_entity ssh.AuthEntity;
	l_project_id uuid;	
	l_workspace_id uuid;
	l_project_owner uuid;
	l_workspace_owner uuid;
	l_selector ltree;
BEGIN
	l_entity := ssh.check_auth_force(entity);	
	select p.id, p.workspace_id, p.owner, w.owner from projects.projects p
	inner join workspaces.workspaces w on (w.id = p.workspace_id)
	where p.id = project_id
	into l_project_id, l_workspace_id, l_project_owner, l_workspace_owner;	
	if (l_project_id is null) then
		raise exception 
    	using
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'PROJECT_NO_ACCESS', 'status', 401)::text;
	end if;

	if (l_entity.id = l_project_owner) or (l_entity.id = l_workspace_owner) then
		return;
	end if;

	l_selector := users.check_workspace_selectors(l_entity.id, l_workspace_id, ARRAY['root.workspace.write.admin']::ltree[]);
	if (l_selector is not null) then
		return;
	end if;

	perform users.check_project_selectors_force(l_entity.id, project_id, a_selectors);
END;
$$ LANGUAGE plpgsql;

create or replace function projects.set_keys(
    project_id uuid,
    key_data jsonb,
    entity ssh.AuthEntity
)
RETURNS void AS $$
DECLARE
    ws jsonb;
BEGIN
    IF jsonb_typeof(key_data) != 'array' THEN
        RAISE EXCEPTION 
            USING 
                ERRCODE = 'EJSON',
                DETAIL = jsonb_build_object('code', 'KEYS_NOT_ARRAY', 'status', 400)::text;
    END IF;

    FOR ws IN
        SELECT jsonb_array_elements(key_data)
    LOOP
        PERFORM projects.set_key(project_id, ws, entity);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


create or replace function projects.set_key(a_project_id uuid, key_data jsonb, entity ssh.AuthEntity)
RETURNS void AS $$
DECLARE 		
		l_key text;
		l_value text;
BEGIN
		l_key := shared.set_null_if_empty(key_data->>'key');
		IF (l_key IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'KEY_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_value := shared.set_null_if_empty(key_data->>'value');
		IF (l_value IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'VALUE_IS_EMPTY', 'status', 400)::text;
		END IF;
		
		PERFORM projects.check_access_force(entity, a_project_id, ARRAY['root.workspace.project.write']::ltree[]);
		insert into projects.keys(project_id, key, value)
		values (a_project_id, l_key, l_value)
		on conflict (project_id, key, value) do update
			set value = excluded.value,
					update_time = now();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.get_project(project_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_id uuid;
		l_signer ssh.AuthEntity;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(project_data->>'id')::uuid;
		IF (l_id IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ID_IS_EMPTY', 'status', 400)::text;
		END IF;
		l_signer := ssh.get_auth_entity(project_data->'signer');
		perform projects.check_access_force(l_signer, l_id, ARRAY['root.workspace.project.read']::ltree[]);
		select jsonb_build_object(
							'id', p.id,
							'keys', k.keys,
				      'status', 200
					 ) from projects.projects p
		inner join (
			select project_id, jsonb_agg(jsonb_build_object(
				'key', key,
				'value', value
			)) as keys
			from projects.keys 			
			where project_id = l_id
			group by project_id
		) k on true
		into res;

		return res;
			
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


