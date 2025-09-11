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


create table users.users_to_projects (
	user_id uuid references users.users (id),
	project_id uuid references projects.projects (id),
	primary key (user_id, project_id)
);

create index on users.users_to_projects using hash (user_id);
create index on users.users_to_projects using hash (project_code);

 
CREATE OR REPLACE FUNCTION users.add_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
		l_id uuid;
		l_username text;
    l_email text;
		l_entity ssh.AuthEntity;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
		IF (l_email IS NULL) THEN
			RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'EMAIL_IS_EMPTY', 'status', 400)::text;
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

		l_entity := ssh.get_auth_entity(user_data);
		l_entity.id := l_id;		
		l_entity := ssh.add_key(l_entity);

    RETURN json_build_object(
        'id', l_id,
				'username', l_username,
        'password', l_entity.password,
				'status',	200
    );		
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.update_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_id uuid;
    l_email text;
		l_entity ssh.AuthEntity;

BEGIN
	l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
  l_email := shared.set_null_if_empty(user_data->>'email');        
	l_entity := ssh.get_auth_entity(user_data);
  PERFORM ssh.check_auth_force(l_entity);
  UPDATE users.users u
  	SET
    	email = COALESCE(l_email, u.email),
      last_visited = now(),
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
			DETAIL = json_build_object('code', 'USER_NOT_FOUND', 'status', 404)::text;    
  END IF;

	PERFORM ssh.update_key(l_entity);
	RETURN res;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION users.set_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;		
		l_id uuid;
		v_detail text;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			return users.add_user(user_data);
		end if;
		return users.update_user(user_data);
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
    l_entity.id := ssh.check_auth_force(l_entity);
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


select * from users.users;
select * from workspaces.workspaces;
