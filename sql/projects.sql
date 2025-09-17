create schema if not exists projects;

drop table projects.projects cascade;

create table projects.projects(
	id uuid primary key default gen_random_uuid(),
	name text not null,
	description text,
	workspace_id uuid not null references workspaces.workspaces on delete cascade,
	owner_id uuid not null references users.users on delete cascade,
	create_time timestamp with time zone not null default now(),
	update_time timestamp with time zone not null default now(),
	unique (workspace_id, name)
);

create index on projects.projects using hash (workspace_id);
create index on projects.projects using hash (owner_id);


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


CREATE OR REPLACE FUNCTION projects.set_project(project_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_id uuid;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(project_data->>'id')::uuid;
		if (l_id is null) then
			return projects.add_project(project_data);
		end if;
		return projects.update_project(project_data);
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.add_project(project_data jsonb)
RETURNS json AS $$
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
					DETAIL = json_build_object('code', 'NAME_IS_EMPTY', 'status', 400)::text;
		END IF;

   l_workspace_id := shared.set_null_if_empty(project_data->>'workspaceId');
		IF (l_workspace_id IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'WORKSPACE_ID_IS_EMPTY', 'status', 400)::text;
		END IF;

    l_description := shared.set_null_if_empty(project_data->>'description');

		l_entity := ssh.get_auth_entity(project_data->'user');
		l_owner_id := ssh.check_auth_force(l_entity);

    INSERT INTO projects.projects (
				name,
				workspace_id,
				description,
				owner_id
    )
    VALUES (
        l_name,
				l_workspace_id,
				l_description,
				l_owner_id
    )
    RETURNING id
		INTO l_id;

    RETURN json_build_object(
        'id', l_id,
				'name', l_name,
        'description', l_description,
				'status',	200
    );
	END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projects.update_project(project_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_id uuid;
    l_name text;
		l_entity ssh.AuthEntity;
		l_owner uuid;
BEGIN
    l_id := shared.set_null_if_empty(project_data->>'id');
    l_name := shared.set_null_if_empty(project_data->>'name');

		l_entity := ssh.get_auth_entity(project_data->'user');
		l_owner := shared.set_null_if_empty(project_data->>'newOwner');
		PERFORM projects.check_access_force(l_entity, l_id);

    UPDATE projects.projects p
    	SET
        name = COALESCE(l_name, p.name),
        description = COALESCE(l_description, p.description),
				owner = COALESCE(l_owner, p.owner),
				update_time = now()
      WHERE id = l_id
      	RETURNING json_build_object(
        	'id', p.id,
          'status', 200
       	) INTO res;

      IF res IS NULL THEN
		  	RAISE EXCEPTION 
    			USING 
						ERRCODE = 'EJSON', 
						DETAIL = json_build_object('code', 'PROJECT_NOT_FOUND', 'status', 404)::text;
      END IF;

     RETURN res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.delete_project(project_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_entity ssh.AuthEntity;
		l_id uuid;
		v_detail text;
BEGIN
  l_id := shared.set_null_if_empty(project_data->>'id');
	l_entity := ssh.get_auth_entity(project_data->'user');
	PERFORM projects.check_access_force(l_entity, l_id);

  DELETE FROM projects.projects p
  	WHERE id = l_id
    RETURNING json_build_object(
      'id', p.id,
      'status', 200
    ) INTO res;
    IF res IS NULL THEN
			RAISE EXCEPTION 
    		USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'PROJECT_NOT_FOUND', 'status', 404)::text;        
    END IF;
    RETURN res;

		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t delete project', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projects.check_access_force(entity ssh.AuthEntity, project_id uuid)
RETURNS void AS $$
DECLARE
	l_res uuid;
	l_owner uuid;
	l_project_id uuid;	
BEGIN
	l_owner := ssh.check_auth_force(entity);
	select p.id from projects.projects p
	inner join workspaces.workspaces w on (p.workspace_id = w.id)
	where p.id = project_id and (p.owner_id = l_owner or w.owner = l_owner)
	into l_project_id;	
	if (l_project_id is null) then
		raise exception 
    	using
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'PROJECT_NO_ACCESS', 'status', 401)::text;
	end if;
END;
$$ LANGUAGE plpgsql;


