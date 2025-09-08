CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgsodium;

CREATE TABLE users.users (
	id uuid DEFAULT gen_random_uuid() NOT NULL,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT NULL,
	last_visited timestamptz DEFAULT now() NOT null,	 
	email text not null,
	username text not null,
	public_key bytea not null,
	password text not null,
	unique(public_key),
	CONSTRAINT users_pkey PRIMARY KEY (id)
);

drop table users.users;

 
CREATE OR REPLACE FUNCTION users.add_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_key bytea;
		l_username text;
    l_password text;
    l_email text;
    l_password_plain text;
BEGIN
    l_email := shared.set_null_if_empty(user_data->>'email');
		IF (l_email IS NULL) THEN
	     RETURN json_build_object(
            'error', 'Can`t add user',
            'code', 'EMAIL_IS_EMPTY',
						'status', 400
       );
		END IF;

    l_key := ssh.get_public_key(user_data->>'publicKey');
    l_username := ssh.get_public_key_username(user_data->>'publicKey');
		IF (l_key IS NULL) THEN
	     RETURN json_build_object(
            'error', 'Can`t add user',
            'code', 'PUBLIC_KEY_IS_EMPTY',
						'status', 400
       );
		END IF;

    l_password_plain := shared.generate_password(16);
    l_password := shared.hash_password(l_password_plain);
	
    INSERT INTO users.users (
        email,
				username,
        public_key,
        password
    )
    VALUES (
        l_email,
				l_username,
        l_key,				
        l_password
    )
    RETURNING json_build_object(
        'id', id,
				'username', l_username,
        'password', l_password_plain,
				'status',	200
    ) INTO res;

    RETURN res;

		EXCEPTION
    	WHEN others THEN
        RETURN json_build_object(
            'error', 'Can`t add user',
            'code', SQLSTATE,
						'status', 500,
						'errorDescription', SQLERRM
        );
		END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.update_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
    l_id uuid;
    l_email text;
    l_key bytea;
    l_new_password text; 
BEGIN
    l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
    l_email := shared.set_null_if_empty(user_data->>'email');
    l_key := ssh.get_public_key(user_data->>'publicKey');
    l_new_password := shared.set_null_if_empty(user_data->>'newPassword');

    IF users.check_auth(user_data) THEN
    	UPDATE users.users u
        SET
            email = COALESCE(l_email, u.email),
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
            RETURN json_build_object('status', 404, 'error', 'user not found');    
        END IF;
        RETURN res;
    ELSE
        RETURN json_build_object('status', 401, 'error', 'unauthorized');
    END IF;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION users.check_auth(user_data jsonb)
RETURNS bool AS $$
DECLARE 
    l_id uuid;
    l_password text; 
    l_key bytea;
    l_message text;
    l_signature bytea;
    l_public_key bytea;
    l_hashed_password text;
    l_res bool;
BEGIN
    l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
    l_password := shared.set_null_if_empty(user_data->>'password');
    l_key := ssh.get_public_key(user_data->>'publicKey');
    l_message := shared.set_null_if_empty(user_data->>'message');
    l_signature := decode(shared.set_null_if_empty(user_data->>'signature'), 'base64');

    IF l_key IS NOT NULL AND l_message IS NOT NULL AND l_signature IS NOT NULL THEN
        SELECT pgsodium.crypto_sign_verify_detached(l_signature, convert_to(l_message, 'UTF8'), public_key)
        FROM users.users
        WHERE id = l_id
        INTO l_res;
        RETURN coalesce(l_res, true);
    END IF;

    SELECT password
      INTO l_hashed_password
      FROM users.users
      WHERE id = l_id;

    IF l_hashed_password IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN shared.verify_password(l_password, l_hashed_password);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION users.set_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_id uuid;
    l_key bytea;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id')::uuid;
		if (l_id is null) then
			return users.add_user(user_data);
		end if;
		return users.update_user(user_data);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION users.delete_user(user_data jsonb)
RETURNS json AS $$
DECLARE 
    res json;
		l_key bytea;
BEGIN
    l_key := ssh.get_public_key(user_data->>'publicKey');
    IF users.check_auth(user_data) THEN
    	DELETE FROM users.users u
      WHERE public_key = l_key
        RETURNING json_build_object(
            'id', u.id,
            'status', 200
        ) INTO res;

        IF res IS NULL THEN
            RETURN json_build_object('status', 404, 'error', 'user not found');    
        END IF;
        RETURN res;
    ELSE
        RETURN json_build_object('status', 401, 'error', 'unauthorized');
    END IF;

END;
$$ LANGUAGE plpgsql;




select * from users.users;



