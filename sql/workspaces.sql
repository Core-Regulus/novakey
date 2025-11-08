create schema if not exists workspaces;

CREATE TABLE workspaces.workspaces (
	id uuid primary key DEFAULT gen_random_uuid() NOT NULL,
	name text not null,
	description text,
	owner uuid not null references users.users (id) on delete cascade,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT null  
);

CREATE OR REPLACE FUNCTION workspaces.set_workspace(workspace_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_id uuid;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(workspace_data->>'id')::uuid;
		if (l_id is null) then
			return workspaces.add_workspace(workspace_data);
		end if;
		return workspaces.update_workspace(workspace_data);		
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t set workspace', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION workspaces.add_workspace(workspace_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    l_email text;
		l_name text;
		l_description text;
		l_id uuid;
		l_entity ssh.AuthEntity;
BEGIN
    l_name := shared.set_null_if_empty(workspace_data->>'name');
		IF (l_name IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'NAME_IS_EMPTY', 'status', 400)::text;
		END IF;

		l_entity := ssh.check_auth_force(workspace_data->'signer');
    l_description := shared.set_null_if_empty(workspace_data->>'description');

    INSERT INTO workspaces.workspaces (
				name,
				description,
				owner
    )
    VALUES (
				l_name,
				l_description,
				l_entity.id
    )
    RETURNING id
		INTO l_id;
 		
    RETURN jsonb_build_object(
        'id', l_id,
				'name', l_name,
				'description', l_description,
				'roleCode', users.get_user_workspace_role(l_id, l_entity.id),
				'status',	200
    );
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.update_workspace(workspace_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
    l_id uuid;
    l_name text;
		l_description text;
		l_entity ssh.AuthEntity;
		l_owner uuid;
BEGIN
    l_id := shared.set_null_if_empty(workspace_data->>'id');
    l_name := shared.set_null_if_empty(workspace_data->>'name');
		l_entity := ssh.check_auth_force(workspace_data->'signer');
		l_owner := shared.set_null_if_empty(workspace_data->>'newOwner');
				 
		PERFORM workspaces.check_access_force(l_entity, l_id, ARRAY['root.workspace.write']::ltree[]);

    UPDATE workspaces.workspaces u
    	SET
        name = COALESCE(l_name, u.name),
        description = COALESCE(l_description, u.description),
				owner = COALESCE(l_owner, u.owner),
				update_time = now()
      WHERE id = l_id
      	RETURNING jsonb_build_object(
        	'id', u.id,
					'name', u.name,
					'description', u.description,
					'roleCode', users.get_user_workspace_role(l_id, u.owner),
          'status', 200
       	) INTO res;

      IF res IS NULL THEN
		  	RAISE EXCEPTION 
    			USING 
						ERRCODE = 'EJSON', 
						DETAIL = jsonb_build_object('code', 'WORKSPACE_NOT_FOUND', 'status', 404)::text;
      END IF;

     RETURN res;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.delete_workspace(workspace_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_entity ssh.AuthEntity;
		l_id uuid;
		v_detail text;
BEGIN
  l_id := shared.set_null_if_empty(workspace_data->>'id');
	l_entity := ssh.check_auth_force(workspace_data->'signer');
	PERFORM workspaces.check_access_force(l_entity, l_id, ARRAY['root.workspace.write.admin']::ltree[]);

  DELETE FROM workspaces.workspaces u
  	WHERE id = l_id
    RETURNING jsonb_build_object(
      'id', u.id,
      'status', 200
    ) INTO res;
    IF res IS NULL THEN
			RAISE EXCEPTION 
    		USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'WORKSPACE_NOT_FOUND', 'status', 404)::text;        
    END IF;
    RETURN res;

		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t delete workspace', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION workspaces.get_workspace(workspace_data jsonb)
RETURNS jsonb AS $$
DECLARE 
    res jsonb;
		l_id uuid;
		l_signer ssh.AuthEntity;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(workspace_data->>'id')::uuid;
		IF (l_id IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = jsonb_build_object('code', 'ID_IS_EMPTY', 'status', 400)::text;
		END IF;
		
		l_signer := ssh.check_auth_force(workspace_data->'signer');
		perform workspaces.check_access_force(l_signer, l_id, ARRAY['root.workspace.read']::ltree[]);
		
		select jsonb_build_object(
							'id', id,
							'name', name,
							'description', description,
							'roleCode', users.get_user_workspace_role(l_id, l_signer.id),
				      'status', 200
					 ) from workspaces.workspaces
		into res;

		return res;
			
		EXCEPTION
			WHEN others THEN
				GET STACKED DIAGNOSTICS
  	      v_detail = PG_EXCEPTION_DETAIL;
				RETURN shared.handle_exception('Can`t get workspace', SQLSTATE, v_detail, SQLERRM);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION workspaces.check_access_force(entity ssh.AuthEntity, workspace_id uuid, a_selectors ltree[])
RETURNS void AS $$
DECLARE
	l_res uuid;
	l_workspace_id uuid;
	l_workspace_owner uuid;
BEGIN

	select id, owner from workspaces.workspaces
	where id = workspace_id
	into l_workspace_id, l_workspace_owner;	

	if (l_workspace_id is null) then
		raise exception 
    	using
				ERRCODE = 'EJSON', 
				DETAIL = jsonb_build_object('code', 'WORKSPACE_NO_ACCESS', 'status', 401)::text;
	end if;

	if (entity.id = l_workspace_owner) then
		return;
	end if;
	
	perform users.check_workspace_selectors_force(entity.id, workspace_id, a_selectors);

END;
$$ LANGUAGE plpgsql;

