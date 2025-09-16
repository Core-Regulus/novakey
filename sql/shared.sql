create schema shared;

CREATE OR REPLACE FUNCTION shared.is_empty(value text)
RETURNS bool AS $$
DECLARE 
BEGIN
		return (value is null) or (value = '') or (value = '00000000-0000-0000-0000-000000000000');
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


 
CREATE OR REPLACE FUNCTION shared.handle_exception(message text, state text, detail text, description text)
RETURNS json AS $$
DECLARE
	res json;
BEGIN
	IF state = 'EJSON' THEN
		res := detail::json;
		RETURN json_build_object(
       'error', message,
       'code', res->>'code',
			 'status', (res->>'status')::int,
			 'errorDescription', description
    );
	END IF;
	
	RETURN json_build_object(
  	'error', message,
    'code', state,
		'status', 500,
		'errorDescription', description
   );
END;
$$ LANGUAGE plpgsql;

