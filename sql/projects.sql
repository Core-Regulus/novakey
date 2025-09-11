create schema if not exists projects;

create table projects.projects(
	id uuid primary key,
	workspace_id uuid references workspaces.workspaces (id),
	description text
);



create index on projects.projects using hash (workspace_id);



create table projects.keys (
	project_id uuid references projects.projects (id),
	key text,	
	value text,
	primary key (project_id, key),
	unique(key, value)
);

create index on projects.keys using hash (project_id);





