CREATE SCHEMA is not exists ssh;

CREATE TABLE ssh.keys (
	id uuid primary key,
	public_key bytea not null,
	password text not null,
	create_time timestamptz DEFAULT now() NOT NULL,
	update_time timestamptz DEFAULT now() NOT NULL,	 
	unique(public_key)
);

create index on ssh.keys using hash (public_key);

CREATE TYPE ssh.AuthEntity AS (
    id   uuid,
    public_key  bytea,
    password    text,
    message			bytea,
    signature		bytea,
    new_password text
);

create type ssh.EntityResult as (
	data jsonb,
	entity ssh.AuthEntity
);


CREATE OR REPLACE FUNCTION ssh.public_key_to_bytea(pubkey TEXT)
RETURNS BYTEA AS $$
DECLARE
	l_decoded BYTEA;
	len int;
BEGIN
  IF shared.is_empty(pubkey) = TRUE THEN
    RETURN NULL;
  END IF;

  IF NOT (pubkey LIKE 'ssh-ed25519 %' OR pubkey LIKE 'ssh-rsa %') THEN
    RAISE EXCEPTION 'Unsupported key type: %', split_part(pubkey, ' ', 1);
  END IF;

  l_decoded := decode(split_part(pubkey, ' ', 2), 'base64');

	len := octet_length(l_decoded);  
  RETURN substring(l_decoded FROM len - 32 + 1 FOR 32);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION ssh.get_public_key_username(pubkey TEXT)
RETURNS TEXT AS $$
BEGIN
  IF pubkey IS NULL THEN
    RETURN NULL;
  END IF;

  IF NOT (pubkey LIKE 'ssh-ed25519 %' OR pubkey LIKE 'ssh-rsa %') THEN
    RAISE EXCEPTION 'Unsupported key type: %', split_part(pubkey, ' ', 1);
  END IF;

  RETURN split_part(pubkey, ' ', 3);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION ssh.get_public_key(public_key text)
RETURNS BYTEA AS $$
BEGIN
	IF public_key IS NULL THEN
		RETURN NULL;
	END IF;

	RETURN ssh.public_key_to_bytea(public_key);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION ssh.hash_password(password text)
RETURNS text AS $$
BEGIN
    IF password IS NULL OR length(password) = 0 THEN
       return NULL;
    END IF;

    RETURN crypt(password, gen_salt('bf', 12));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ssh.verify_password(password text, hashed text)
RETURNS boolean AS $$
BEGIN		
    RETURN crypt(password, hashed) = hashed;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION ssh.generate_password(length int DEFAULT 12)
RETURNS text AS $$
DECLARE
    raw_bytes bytea;
    base64_pass text;
BEGIN
    IF length < 6 THEN
        RAISE EXCEPTION 'Password length must be at least 6 characters';
    END IF;

    raw_bytes := gen_random_bytes(length);
    base64_pass := encode(raw_bytes, 'base64');
    base64_pass := regexp_replace(base64_pass, E'[\\n\\r]', '', 'g');
    RETURN left(base64_pass, length);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ssh.check_auth(entity ssh.AuthEntity)
RETURNS uuid AS $$
DECLARE 
    l_hashed_password text;
    l_res uuid;
BEGIN
    IF entity.public_key IS NOT NULL AND entity.message IS NOT NULL AND entity.signature IS NOT NULL THEN       
			SELECT id
        FROM ssh.keys
        WHERE public_key = entity.public_key AND
							pgsodium.crypto_sign_verify_detached(entity.signature, entity.message, entity.public_key) = TRUE
        INTO l_res;
				IF l_res IS NOT NULL THEN
					RETURN l_res;
				END IF;
    END IF;

		SELECT id, password
      INTO l_res, l_hashed_password
      FROM ssh.keys
      WHERE id = entity.id;

		IF l_hashed_password IS NULL THEN
        RETURN NULL;
    END IF;
		
    IF ssh.verify_password(entity.password, l_hashed_password) = TRUE THEN			
			return l_res;
		END IF;

		RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ssh.check_auth_force(entity ssh.AuthEntity)
RETURNS ssh.AuthEntity AS $$
BEGIN
	entity.id := ssh.check_auth(entity);
	IF entity.id IS NULL THEN
		RAISE EXCEPTION 
			USING
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'UNAUTHORIZED', 'status', 401)::text;
	END IF;
	RETURN entity;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ssh.check_auth_force(user_data jsonb)
RETURNS ssh.AuthEntity AS $$
DECLARE
	l_entity ssh.AuthEntity;
BEGIN
	l_entity := ssh.get_auth_entity(user_data);
	l_entity.id := ssh.check_auth(l_entity);
	IF l_entity.id IS NULL THEN
		RAISE EXCEPTION
			USING
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'UNAUTHORIZED', 'status', 401)::text;
	END IF;
	RETURN l_entity;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION ssh.get_auth_entity(user_data jsonb)
RETURNS ssh.AuthEntity AS $$
DECLARE 
	l_entity ssh.AuthEntity;	
BEGIN
	 l_entity.id := shared.set_null_if_empty(user_data->>'id')::uuid;    
   l_entity.public_key := ssh.get_public_key(user_data->>'publicKey');
   l_entity.password := shared.set_null_if_empty(user_data->>'password');
	 l_entity.message := decode(shared.set_null_if_empty(user_data->>'message'), 'base64');
	 l_entity.signature := decode(shared.set_null_if_empty(user_data->>'signature'), 'base64');
   l_entity.new_password := shared.set_null_if_empty(user_data->>'newPassword'); 
	 return l_entity;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION ssh.get_signer(signer_data jsonb, default_signer ssh.AuthEntity)
RETURNS ssh.AuthEntity AS $$
DECLARE 	
	l_signer ssh.AuthEntity;
BEGIN
	l_signer := ssh.get_auth_entity(signer_data);
	l_signer.id := ssh.check_auth(l_signer);
	if (l_signer.id is null) then 
		return default_signer;
	end if;
	return l_signer;		 
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION ssh.add_key(entity ssh.AuthEntity)
RETURNS ssh.AuthEntity AS $$
DECLARE 
    l_password text;
BEGIN
		IF (entity.id IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'ENTITY_ID_IS_EMPTY', 'status', 400)::text;
		END IF;

		IF (entity.public_key IS NULL) THEN
    	RAISE EXCEPTION 
      	USING 
					ERRCODE = 'EJSON', 
					DETAIL = json_build_object('code', 'PUBLIC_KEY_IS_EMPTY', 'status', 400)::text;
		END IF;

    entity.password := ssh.generate_password(16);
    l_password := ssh.hash_password(entity.password);
	
    INSERT INTO ssh.keys (
				id,
        public_key,
        password
    )
    VALUES (
			entity.id,
			entity.public_key,
			l_password			
    );

		RETURN entity;
END;    
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ssh.update_key(entity ssh.AuthEntity)
RETURNS ssh.AuthEntity AS $$
BEGIN
   UPDATE ssh.keys s
   	SET
      public_key = COALESCE(entity.public_key, s.public_key),
      update_time = now(),
      password = COALESCE(shared.hash_password(entity.new_password), s.password)
    WHERE id = entity.id
    	RETURNING id				
			INTO entity.id;

    IF entity.id IS NULL THEN
			RETURN ssh.add_key(entity);
    END IF;
		RETURN entity;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ssh.delete_key(entity ssh.AuthEntity)
RETURNS ssh.AuthEntity AS $$
DECLARE
	l_res uuid;
BEGIN
	DELETE FROM ssh.keys s
  	WHERE public_key = entity.public_key or id = entity.id
	RETURNING id
	INTO l_res;

  IF l_res IS NULL THEN
		RAISE EXCEPTION 
			USING
				ERRCODE = 'EJSON', 
				DETAIL = json_build_object('code', 'KEY_NOT_FOUND', 'status', 404)::text;    
  END IF;
  RETURN entity;
END;
$$ LANGUAGE plpgsql;


