CREATE SCHEMA ssh;

CREATE OR REPLACE FUNCTION ssh.public_key_to_bytea(pubkey TEXT)
RETURNS BYTEA AS $$
BEGIN
  IF pubkey IS NULL THEN
    RETURN NULL;
  END IF;

  IF NOT (pubkey LIKE 'ssh-ed25519 %' OR pubkey LIKE 'ssh-rsa %') THEN
    RAISE EXCEPTION 'Unsupported key type: %', split_part(pubkey, ' ', 1);
  END IF;

  RETURN decode(split_part(pubkey, ' ', 2), 'base64');
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
