create schema if not exists roles;

CREATE TABLE if not exists roles.roles (
	code ltree primary key,	
	name text not null,
	description text not null, 
	display_order int not null default 0,
	create_time timestamptz DEFAULT now() NOT null
);


CREATE TABLE if not exists roles.selectors (
	code ltree primary key,
	description text,
	create_time timestamptz DEFAULT now() NOT NULL
);

CREATE TABLE if not exists roles.profiles (
	role_code ltree not null references roles.roles (code) on delete cascade,
	selector_code ltree not null references roles.selectors(code),
	create_time timestamptz DEFAULT now() NOT null,
	primary key(role_code, selector_code)
);


create index on roles.profiles using gist (role_code);
create index on roles.profiles using gist (selector_code);

insert into roles.roles (code, name, description, display_order)
values 
('root.workspace.admin', 'Workspace Admin', 'Can modify workspace system-related settings', 1),
('root.workspace.writer', 'Workspace Writer',  'Can modify workspace user related settings', 2),
('root.workspace.reader', 'Workspace Reader', 'Can read all workspace data', 3),
('root.workspace.user', 'Workspace User', 'Can read only from specific projects', 4),
('root.workspace.project.admin', 'Project Admin', 'Can modify project system-related settings', 1),
('root.workspace.project.reader', 'Project Reader', 'Can read project data', 2),
('root.workspace.project.writer', 'Project Writer', 'Can modify user-related settings', 3)
on conflict (code) do update
	set name = excluded.name,
			display_order = excluded.display_order


insert into roles.selectors (code, description)
values 
('root.workspace.write.admin', 'Can change system properties of workspace'),
('root.workspace.write', 'Has access to modify all projects in workspace'),
('root.workspace.read', 'Has access to read all projects in workspace'),
('root.workspace.project.admin', 'Can set system properties of project'),
('root.workspace.project.write', 'Can write into project'),
('root.workspace.project.read', 'Can read from project')
on conflict (code) do update
	set description = excluded.description;

insert into roles.profiles (role_code, selector_code)
values ('root.workspace.admin', 'root.workspace.write.admin'),
			 ('root.workspace.writer', 'root.workspace.write'),
			 ('root.workspace.reader', 'root.workspace.read'),
			 ('root.workspace.project.reader', 'root.workspace.project.read'),
			 ('root.workspace.project.writer', 'root.workspace.project.write'),
			 ('root.workspace.project.writer', 'root.workspace.project.read'),
			 ('root.workspace.project.admin', 'root.workspace.project.admin'),
			 ('root.workspace.project.admin', 'root.workspace.project.read'),
			 ('root.workspace.project.admin', 'root.workspace.project.write')
on conflict (role_code, selector_code) do update
	set selector_code = excluded.selector_code;


select * from users.users_projects up;




	select p.selector_code from users.users_projects w
	inner join roles.profiles p on (p.role_code = w.role_code)
	where (w.user_id = 'b2cea625-0db4-4a44-bdb5-be26f82211b9' and 
				w.project_id = '3e450a66-a37d-48bc-82ca-99d62bf62700' and 
				p.selector_code = any(array['root.workspace.project.read']::ltree[]));



