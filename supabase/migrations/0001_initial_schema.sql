-- MemberDesk initial schema. Run in a fresh Supabase project as database owner.
create extension if not exists pgcrypto;

create type public.member_type as enum ('gym','library');
create type public.user_role as enum ('owner','staff');
create type public.payment_method as enum ('cash','upi','bank_transfer','card','other');
create type public.payment_status as enum ('paid','partially_refunded','refunded');
create type public.membership_status as enum ('active','expired','paused','cancelled');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  timezone text not null default 'Asia/Kolkata',
  currency_code char(3) not null default 'INR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  full_name text not null,
  role public.user_role not null default 'staff',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_org_idx on public.profiles(organization_id);

create function public.current_org_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.organization_id from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true limit 1;
$$;
create function public.current_user_role() returns public.user_role
language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p
  where p.id = (select auth.uid()) and p.is_active = true limit 1;
$$;
create function public.is_org_owner() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.current_user_role() = 'owner', false);
$$;

create table public.members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  member_code text not null,
  member_type public.member_type not null,
  full_name text not null,
  phone text,
  email text,
  address text,
  emergency_contact text,
  joined_on date not null default current_date,
  notes text,
  is_active boolean not null default true,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, member_code),
  check (phone is null or length(phone) <= 30),
  check (email is null or length(email) <= 254)
);
create index members_org_type_idx on public.members(organization_id, member_type);
create index members_org_name_idx on public.members(organization_id, full_name);
create index members_org_phone_idx on public.members(organization_id, phone);

create table public.gym_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null,
  duration_days integer not null check (duration_days between 1 and 730),
  price_paise bigint not null check (price_paise >= 0),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table public.library_seats (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  seat_code text not null,
  zone text,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  unique (organization_id, seat_code)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete restrict,
  member_type public.member_type not null,
  gym_plan_id uuid references public.gym_plans(id) on delete set null,
  library_seat_id uuid references public.library_seats(id) on delete set null,
  start_date date not null,
  end_date date not null,
  amount_paise bigint not null check (amount_paise >= 0),
  status public.membership_status not null default 'active',
  notes text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (end_date >= start_date),
  check ((member_type = 'gym' and library_seat_id is null) or (member_type = 'library' and gym_plan_id is null))
);
create index memberships_org_end_date_idx on public.memberships(organization_id, end_date, status);
create index memberships_member_idx on public.memberships(member_id, start_date desc);

-- Prevent overlapping active date ranges for the same fixed library seat.
create extension if not exists btree_gist;
alter table public.memberships add constraint library_seat_no_overlapping_active_memberships
exclude using gist (library_seat_id with =, daterange(start_date, end_date, '[]') with &&)
where (member_type = 'library' and status = 'active' and library_seat_id is not null);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  receipt_number text not null,
  member_id uuid not null references public.members(id) on delete restrict,
  membership_id uuid references public.memberships(id) on delete set null,
  amount_paise bigint not null check (amount_paise > 0),
  method public.payment_method not null,
  status public.payment_status not null default 'paid',
  paid_at timestamptz not null default now(),
  reference_number text,
  notes text,
  received_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (organization_id, receipt_number)
);
create index payments_org_paid_at_idx on public.payments(organization_id, paid_at desc);
create index payments_member_idx on public.payments(member_id, paid_at desc);

create table public.attendance (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  member_type public.member_type not null,
  attended_at timestamptz not null default now(),
  check_in_by uuid default auth.uid() references auth.users(id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);
create index attendance_org_date_idx on public.attendance(organization_id, attended_at desc);
create index attendance_member_date_idx on public.attendance(member_id, attended_at desc);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  category text not null,
  description text not null,
  amount_paise bigint not null check (amount_paise > 0),
  spent_on date not null default current_date,
  payment_method public.payment_method not null default 'cash',
  vendor_name text,
  reference_number text,
  created_by uuid default auth.uid() references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index expenses_org_spent_on_idx on public.expenses(organization_id, spent_on desc);

create table public.notification_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  member_id uuid references public.members(id) on delete set null,
  membership_id uuid references public.memberships(id) on delete set null,
  channel text not null check (channel in ('email','sms','whatsapp','in_app')),
  template_key text not null,
  scheduled_for timestamptz,
  sent_at timestamptz,
  status text not null default 'queued' check (status in ('queued','sent','failed','cancelled')),
  provider_reference text,
  error_summary text,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  table_name text not null,
  record_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_log_org_created_idx on public.audit_log(organization_id, created_at desc);

-- Updated timestamp helper.
create function public.set_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
create trigger organizations_updated_at before update on public.organizations for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger members_updated_at before update on public.members for each row execute function public.set_updated_at();

-- Row Level Security: all operational data is restricted to the signed-in user's organization.
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.gym_plans enable row level security;
alter table public.library_seats enable row level security;
alter table public.memberships enable row level security;
alter table public.payments enable row level security;
alter table public.attendance enable row level security;
alter table public.expenses enable row level security;
alter table public.notification_log enable row level security;
alter table public.audit_log enable row level security;

create policy "users read their organization" on public.organizations for select to authenticated using (id = (select public.current_org_id()));
create policy "owners update their organization" on public.organizations for update to authenticated using (id = (select public.current_org_id()) and (select public.is_org_owner())) with check (id = (select public.current_org_id()) and (select public.is_org_owner()));
create policy "users read same org profiles" on public.profiles for select to authenticated using (organization_id = (select public.current_org_id()));
create policy "owners manage profiles" on public.profiles for all to authenticated using (organization_id = (select public.current_org_id()) and (select public.is_org_owner())) with check (organization_id = (select public.current_org_id()) and (select public.is_org_owner()));

-- Staff can operate member, fee, attendance and expense workflows. Owner-only actions
-- (staff management and organization settings) are separated above. Audit/notification logs are read-only for staff.
create policy "org members access" on public.members for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org gym plans access" on public.gym_plans for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org seats access" on public.library_seats for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org memberships access" on public.memberships for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org payments access" on public.payments for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org attendance access" on public.attendance for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org expenses access" on public.expenses for all to authenticated using (organization_id = (select public.current_org_id())) with check (organization_id = (select public.current_org_id()));
create policy "org notification read" on public.notification_log for select to authenticated using (organization_id = (select public.current_org_id()));
create policy "org audit read" on public.audit_log for select to authenticated using (organization_id = (select public.current_org_id()));

-- Prevent direct client-side role escalation. Profile role/organization changes must be performed
-- through a trusted administrative process, not by ordinary authenticated clients.
create function public.prevent_profile_privilege_escalation() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and (new.role is distinct from old.role or new.organization_id is distinct from old.organization_id or new.id is distinct from old.id) then
    raise exception 'Profile role and organization changes require a trusted administrative process';
  end if;
  return new;
end; $$;
create trigger profiles_protect_privileges before update on public.profiles for each row execute function public.prevent_profile_privilege_escalation();

-- NOTE: Bootstrap the first organization and owner profile via Supabase SQL Editor/service role.
-- Never expose a service-role key to the browser. See README for bootstrap notes.
