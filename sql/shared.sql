create schema shared;

CREATE OR REPLACE FUNCTION shared.is_empty(value text)
RETURNS bool AS $$
DECLARE 
BEGIN
		return (value is null) or (value = '');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION shared.set_null_if_empty(value text)
RETURNS text AS $$
DECLARE 
BEGIN
	if (shared.is_empty(value)) then
		return null;
	end if;
	return value;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION shared.get_bool(value text)
RETURNS boolean AS $$
BEGIN
    IF shared.is_empty(value) THEN
        RETURN FALSE;
    END IF;

    RETURN value::boolean;
EXCEPTION
    WHEN invalid_text_representation THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION shared.hash_password(password text)
RETURNS text AS $$
BEGIN
    IF password IS NULL OR length(password) = 0 THEN
       return NULL;
    END IF;

    RETURN crypt(password, gen_salt('bf', 12));
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION shared.verify_password(password text, hashed text)
RETURNS boolean AS $$
BEGIN		
    RETURN crypt(password, hashed) = hashed;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE OR REPLACE FUNCTION shared.generate_password(length int DEFAULT 12)
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

CREATE OR REPLACE FUNCTION shared.check_auth(user_data jsonb)
RETURNS bool AS $$
DECLARE 
    l_id uuid;
    l_password text; 
    l_key bytea;
    l_message bytea;
    l_signature bytea;
    l_public_key bytea;
    l_hashed_password text;
    l_res bool;
BEGIN
		l_id := shared.set_null_if_empty(user_data->>'id');    
		l_password := shared.set_null_if_empty(user_data->>'password');
    l_key := ssh.get_public_key(user_data->>'publicKey');
		l_message := decode(shared.set_null_if_empty(user_data->>'message'), 'base64');
    l_signature := decode(shared.set_null_if_empty(user_data->>'signature'), 'base64');

    IF l_key IS NOT NULL AND l_message IS NOT NULL AND l_signature IS NOT NULL THEN       
			SELECT pgsodium.crypto_sign_verify_detached(l_signature, l_message, public_key)
        FROM users.users
        WHERE public_key = l_key
        INTO l_res;
				IF l_res IS NOT NULL THEN 
					RETURN l_res;
				END IF;
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


