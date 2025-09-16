create schema if not exists roles;

drop table roles.system_roles;

CREATE TABLE roles.system_roles (
	code text primary key,
	create_time timestamptz DEFAULT now() NOT NULL
);


CREATE TABLE roles.workspace_roles (
	code text not null,
	workspace_id uuid not null references workspaces.workspaces (id) on delete cascade,
	create_time timestamptz DEFAULT now() NOT null,
	primary key(code, workspace_id)
);

create index on roles.workspace_roles using hash (workspace_id);


CREATE TABLE roles.selectors (
	code ltree primary key,
	description text,
	create_time timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE roles.system_profiles (
	role_code text not null references roles.system_roles (code) on delete cascade,
	selector_code ltree not null references roles.selectors(code) on delete cascade,
	create_time timestamptz DEFAULT now() NOT null,
	primary key (role_code, selector_code)
);

create index on roles.system_profiles using hash (role_code);
create index on roles.system_profiles using hash (selector_code);


CREATE TABLE roles.workspace_profiles (
	workspace_id uuid not null references workspaces.workspaces (id) on delete cascade,
	role_code text not null,
	selector_code ltree not null references roles.selectors(code) on delete cascade,
	create_time timestamptz DEFAULT now() NOT null,
	primary key(workspace_id, role_code, selector_code),
	foreign key(workspace_id, role_code) 
  references roles.workspace_roles (workspace_id, code)
);

create index on roles.workspace_profiles (workspace_id);
create index on roles.workspace_profiles (selector_code);



