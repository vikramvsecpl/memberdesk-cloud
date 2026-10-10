# MemberDesk Cloud — implementation starter

A responsive Next.js + Supabase foundation for combined Gym and fixed-seat Self-Study Library operations.

## Included in this starter

- Responsive landing page and sign-in screen
- Supabase Auth sign-in flow and middleware protection for `/dashboard/*`
- Dashboard shell
- PostgreSQL schema for organizations, owner/staff profiles, gym/library members, plans, fixed seats, memberships, payments/receipts, attendance, expenses, reminder log and audit log
- Row Level Security (RLS) organization isolation policies
- Library seat overlapping-membership constraint
- Setup checklist and environment-variable example

## Important status

This is an **implementation starter, not a finished production service**. It has not been deployed, penetration-tested, or connected to a live database. The member/fee/attendance CRUD screens, receipt rendering, staff-management UI, reminder worker, backup automation and reports still need implementation and testing before live operation.

## Requirements

- Node.js 20.9+
- A Supabase project
- A hosting account supporting Next.js (for example Vercel)

## Run locally

```bash
npm install
cp .env.example .env.local
# Fill in NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY
npm run dev
```

Open http://localhost:3000.

## Database setup

1. Create a fresh Supabase project.
2. Open SQL Editor and run `supabase/migrations/0001_initial_schema.sql`.
3. Create the initial owner user in Authentication.
4. Bootstrap the organization and owner profile from the Supabase SQL Editor using the created Auth user's UUID. Example (replace placeholders):

```sql
insert into public.organizations (id, name)
values ('11111111-1111-1111-1111-111111111111', 'Business Name To Be Decided');

insert into public.profiles (id, organization_id, full_name, role)
values ('AUTH-USER-UUID-HERE', '11111111-1111-1111-1111-111111111111', 'Owner', 'owner');
```

Use valid UUIDs. Do not paste real credentials into source control or chat. Create staff accounts through a trusted admin workflow; do not grant the client a service-role key. The starter intentionally disables public self-registration.

## Security checklist before launch

- Enable email verification and configure allowed redirect URLs.
- Use strong passwords and enable MFA for owner/admin accounts.
- Keep service-role keys only in server-side secret storage; never use them in browser code.
- Verify RLS policies with separate owner/staff accounts and negative cross-organization tests.
- Add rate limits, security headers, monitoring, and a tested password recovery flow.
- Decide whether staff may edit/refund payments or delete records; add least-privilege policies and immutable audit triggers accordingly.
- Configure managed database backups/PITR where available and test restore.
- Configure and test notification consent, templates, delivery providers, retries, and opt-out handling before reminders are sent.
- Complete privacy review and applicable India data-protection/legal review before storing real member data.

## Suggested delivery phases

1. Core data flows: organization setup, member CRUD, plans/seats, memberships, payment entry and receipt print.
2. Daily operations: attendance, renewals/expiry list, due collection, expenses and exports.
3. Owner/staff administration: invite staff, permissions, audit trail and reports.
4. Automation: scheduled expiry reminders, delivery logs, backups/restore tests.
5. Production hardening: accessibility, security tests, monitoring, load tests and launch checklist.
