create table if not exists contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  details text default '',
  language_code text not null default 'en-US',
  voice_style text not null default 'warm_companion',
  photo_url text,
  ringtone text not null default 'default_call',
  system_prompt text not null,
  created_at timestamptz not null default now()
);

create table if not exists messages (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  contact_id uuid not null references contacts(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  created_at timestamptz not null default now()
);

create table if not exists reminders (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  contact_id uuid not null references contacts(id) on delete cascade,
  task text not null,
  scheduled_at timestamptz not null,
  status text not null default 'scheduled',
  created_at timestamptz not null default now()
);

create index if not exists messages_contact_created on messages(contact_id, created_at desc);
create index if not exists reminders_due on reminders(status, scheduled_at);
