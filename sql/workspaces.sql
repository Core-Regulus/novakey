create schema if not exists workspaces;

CREATE TABLE workspaces.workspaces (
	id uuid DEFAULT gen_random_uuid() NOT NULL,
	name text not null,
	email text not null,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT NULL,	 
	public_key bytea not null,
	password text not null,
	unique(public_key),
	CONSTRAINT users_pkey PRIMARY KEY (id)
);


CREATE OR REPLACE FUNCTION workspaces.set_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_id uuid;
    l_key bytea;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			return workspaces.add_workspace(user_data);
		end if;
		return workspaces.update_workspace(user_data);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.add_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_key bytea;
    l_password text;
    l_email text;
		l_name text;
    l_password_plain text;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
		IF (l_email IS NULL) THEN
	     RETURN json_build_object(
            'error', 'Can`t add workspace',
            'code', 'EMAIL_IS_EMPTY',
						'status', 400
       );
		END IF;

    l_name := shared.set_null_if_empty(user_data->>'name');
		IF (l_name IS NULL) THEN
	     RETURN json_build_object(
            'error', 'Can`t add workspace',
            'code', 'NAME_IS_EMPTY',
						'status', 400
       );
		END IF;


    l_key := ssh.get_public_key(user_data->>'publicKey');
		IF (l_key IS NULL) THEN
	     RETURN json_build_object(
            'error', 'Can`t add workspace',
            'code', 'PUBLIC_KEY_IS_EMPTY',
						'status', 400
       );
		END IF;

    l_password_plain := shared.generate_password(16);
    l_password := shared.hash_password(l_password_plain);
	
    INSERT INTO workspaces.workspaces (
        email,
				name,
        public_key,
        password
    )
    VALUES (
        l_email,
				l_name,
        l_key,				
        l_password
    )
    RETURNING json_build_object(
        'id', id,
				'name', l_name,
        'password', l_password_plain,
				'status',	200
    ) INTO res;

    RETURN res;

		EXCEPTION
    	WHEN others THEN
        RETURN json_build_object(
            'error', 'Can`t add workspace',
            'code', SQLSTATE,
						'status', 500,
						'errorDescription', SQLERRM
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
    l_key bytea;
    l_new_password text; 
BEGIN
    l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
    l_email := shared.set_null_if_empty(user_data->>'email');
    l_name := shared.set_null_if_empty(user_data->>'name');
    l_key := ssh.get_public_key(user_data->>'publicKey');
    l_new_password := shared.set_null_if_empty(user_data->>'newPassword');

    IF shared.check_auth(user_data) THEN
    	UPDATE workspaces.workspaces u
        SET
            email = COALESCE(l_email, u.email),
            name = COALESCE(l_name, u.name),
            public_key = COALESCE(l_key, u.public_key),
            last_visited = now(),
            password = COALESCE(shared.hash_password(l_new_password), u.password)
        WHERE id = l_id
        RETURNING json_build_object(
            'id', u.id,
            'password', l_new_password,
            'status', 200
        ) INTO res;

        IF res IS NULL THEN
            RETURN json_build_object('status', 404, 'error', 'workspace not found');    
        END IF;
        RETURN res;
    ELSE
        RETURN json_build_object('status', 401, 'error', 'unauthorized');
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION workspaces.delete_workspace(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_key bytea;
		l_id uuid;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;    
		l_key := ssh.get_public_key(user_data->>'publicKey');		
    IF shared.check_auth(user_data) = TRUE THEN
    	DELETE FROM workspaces.workspaces u
      	WHERE public_key = l_key or id = l_id
        RETURNING json_build_object(
            'id', u.id,
            'status', 200
        ) INTO res;

        IF res IS NULL THEN
            RETURN json_build_object('status', 404, 'error', 'workspace not found');    
        END IF;
        RETURN res;
    ELSE
        RETURN json_build_object('status', 401, 'error', 'unauthorized');
    END IF;

END;
$$ LANGUAGE plpgsql;
