# Setup

The SaaS runs on Fly.io with its database on Neon. It's a separate deployment: the
single-tenant app stays on Heroku, on `main`, and shares nothing with this one. Never
push this branch to the `heroku` remote.

## Local development

```bash
bin/rails db:create db:migrate db:seed
bin/dev                                  # port 3030 (Hutba uses 3020)
```

| | |
|---|---|
| Landing page | http://localhost:3030 |
| Super admin | http://localhost:3030/admin (`admin@demo.test`) |
| Account dashboard | http://demo.localhost:3030 (`owner@demo.test`) |
| Test terminal | http://terminal1.demo.localhost:3030 |
| Sent emails | http://localhost:3030/letter_opener |

The password for both demo logins is in `db/seeds.rb`.

Chrome and Firefox resolve `*.localhost` on their own. Safari doesn't, so use `lvh.me`
there with `APP_DOMAIN=lvh.me`.

The `eingang` and `cafe` demo terminals only exist for the statistics, their SumUp key is
fake. `terminal1` uses the test provider and works without any keys. Amounts ending in
.13 fail on purpose.

## Production on Fly.io and Neon

These are done once. After them, new accounts and terminals go live without any step from us.

### 1. Neon

The project is `rapid-tree-45075682`, branch `production`, in AWS `eu-central-1` (Frankfurt), next to Fly's `fra`. It's already migrated. The folder is linked to it through `.neon`.

The connection strings are in `.env.neon`, which git ignores. Don't rename it to `.env` or `.env.local`: `dotenv-rails` would load it in development, and `bin/rails db:seed` would then run against production.

- `DATABASE_URL` is the pooled connection (the `-pooler` host), used by the app
- `DATABASE_URL_UNPOOLED` is the direct one, used by migrations (`bin/release`)

Pooled connections run PgBouncer in transaction mode, which can't hold the advisory lock Rails migrations take. `config/database.yml` already turns off prepared statements and advisory locks in production.

To fetch them again, keeping them away from `dotenv`:

```bash
npx neon@latest env pull && mv .env.local .env.neon    # needs Node 20.19+
```

There's deliberately no `neon.ts` or `@neon/*` npm package here. They need Node 20.19+, which breaks `yarn install` on Node 20.9, including in the Dockerfile, and the app doesn't use them.

Consider turning off scale-to-zero on the production compute, so the first donation after a quiet night doesn't wait for it to wake up.

### 2. Fly app

`fly.toml` names the app `digital-donation`. Fly app names are global, so change it if that one is taken, then:

```bash
fly apps create digital-donation --org personal
fly secrets set \
  SECRET_KEY_BASE="$(bin/rails secret)" \
  DATABASE_URL="$(grep '^DATABASE_URL=' .env.neon | cut -d= -f2- | tr -d \'\")" \
  DATABASE_URL_UNPOOLED="$(grep '^DATABASE_URL_UNPOOLED=' .env.neon | cut -d= -f2- | tr -d \'\")" \
  APP_DOMAIN=digital-donation.com \
  CONTACT_EMAIL=info@everline.io \
  MAIL_FROM='Digital Donation <info@digital-donation.com>' \
  POSTMARK_API_KEY=…
fly secrets set FLY_API_TOKEN="$(fly tokens create deploy -x 87600h)"
```

Then the keys that encrypt the payment providers' credentials. `bin/rails db:encryption:init`
prints three values:

```bash
fly secrets set ENCRYPTION_PRIMARY_KEY=… ENCRYPTION_DETERMINISTIC_KEY=… ENCRYPTION_KEY_DERIVATION_SALT=…
```

**Back these up somewhere safe.** Without them every stored API key is unreadable, and
accounts would have to enter theirs again. `SECRET_KEY_BASE` can change; these can't.

### 3. Email (Postmark)

1. In Postmark, create a server for this app and copy its **Server API token** into `POSTMARK_API_KEY`.
2. Verify the sender: either a Sender Signature for `info@digital-donation.com` or the whole `digital-donation.com` domain. Postmark refuses mail from an unverified `MAIL_FROM`.

Until both are done, no email goes out: no donation confirmations, welcome mails or password resets. Donations themselves aren't affected.

To test without delivering anything, use `POSTMARK_API_TEST` as the token. Postmark checks the message and sends nothing.

### 4. Deploy

```bash
fly deploy --ha=false
```

`bin/release` migrates over the direct connection before the new version starts.

This runs two machines: `app`, and `scheduler` for the billing reminders (`bin/scheduler`), because Fly has no scheduler of its own.

Notices about bank transfers to confirm go to `ADMIN_EMAIL` (default `info@everline.io`).

### 5. Domain

```bash
fly ips allocate-v4 --shared
fly ips allocate-v6
fly certs add digital-donation.com
fly certs add "*.digital-donation.com"
fly certs setup "*.digital-donation.com"     # shows the DNS records
```

At the registrar, add:

- `A` and `AAAA` for `@` and for `*`, with the IPs from `fly ips list`
- the `_acme-challenge` `CNAME` the setup command shows, for the wildcard certificate

Don't add a DNS record for an individual account. `*` answers for
`terminal1.acme.digital-donation.com` as well, but only while `acme.digital-donation.com` has no record of its own.

### 6. Terminal addresses

`terminal1.acme.digital-donation.com` is two levels deep, so the `*.digital-donation.com` certificate doesn't
cover it. Each new terminal requests its own certificate through the Fly API
(`app/services/terminal_certificates.rb`). The dashboard shows "being set up" until Fly has
issued it, and failures appear on the super admin overview.

**Try this with one terminal before inviting accounts.** Fly's docs don't say whether a
two-level hostname is accepted. If it isn't, or the limits below get in the way, switch to
`terminal1-acme.digital-donation.com`, which the wildcard certificate covers with no per-terminal step:

```bash
fly secrets set TERMINAL_HOSTS=flat
```

That only applies to new terminals; existing ones keep their stored hostname.

Limits to keep in mind:

- Fly charges $0.10 a month per certificate after the first 10 in the organisation.
- Let's Encrypt issues 50 certificates a week per registered domain.

### 7. Super admin

```bash
fly ssh console
bin/rails admin:create EMAIL=you@example.com NAME="Your Name"
```

Then log in at `https://digital-donation.com/admin`.

### 8. Before going public

- Have the drafts in `app/views/marketing/privacy.html.erb` and `terms.html.erb` reviewed. Company details for the imprint are in `config/application.rb`.
- The money-back guarantee refunds the difference between the yearly fee and the donations received. It's a manual promise: nothing in the app calculates or refunds it.
- Connect a real SumUp account and take a real payment on a real Solo.

## Moving IGBN from Heroku (later, optional)

The migration keeps existing data: if donations or readers exist, they move to an `igbn`
account. Restore a Heroku backup into Neon over the direct connection, then deploy:

```bash
heroku pg:backups:capture --app igbn-donation   # read-only for the app
heroku pg:backups:download --app igbn-donation
pg_restore --no-owner --no-acl -d "$DATABASE_URL_UNPOOLED" latest.dump
fly deploy
```

Afterwards, on `fly ssh console`, give the account an owner, then enter SumUp's keys under
Payments and upload the logo and background under Appearance:

```ruby
Account.find_by!(subdomain: "igbn").users.create!(name: "…", email: "…", password: "…")
```

The restored terminals keep their reader IDs and their old subdomains as slugs.

## Billing

Accounts get 30 days free. After that the plan is paid yearly by bank transfer:

1. The owner requests a transfer under Billing and gets the bank details and a reference (`DD-123`) by email.
2. When the money arrives, open the account in the super admin, or the overview, and choose **Mark as paid**.

Terminals keep running for 14 days after a transfer is requested. Without payment they pause when the trial or paid year ends; the dashboard stays open. During the trial any number of terminals is allowed; after that each one beyond the first is paid for.

An account with no trial and no paid date never expires, which is how to make one free of charge. In `bin/rails console`:

```ruby
Account.find_by!(subdomain: "igbn").update!(trial_ends_at: nil, paid_until: nil)
```

Prices are constants in `app/models/account.rb`, and the wording on the landing page is in `config/locales/marketing/`.
