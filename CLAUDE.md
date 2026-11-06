# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A multi-tenant SaaS for card donations: communities sign up, connect a payment provider and run donation terminals on tablets next to their card readers. It's the SaaS version of the single-tenant IGBN app, which stays on Heroku on `main`. **This branch deploys to Fly.io with a Neon database. Never push it to the `heroku` remote.** See SETUP.md.

The design and tenancy follow the Hutba translation app (`../igbd-translations-app`, hutba.app, locally on port 3020).

## Development Commands

```bash
bin/dev                      # port 3030: Rails and the JS bundler
bin/rails db:seed            # demo account, see SETUP.md for the URLs
bin/rails test
bin/rails test test/models/donation_test.rb
yarn build
```

## Architecture

### Hosts

`config/routes.rb` splits by host:

- `digital-donation.com`: marketing site (`/de`, `/en`, `/bs`) and super admin (`/admin`), via the `AppDomain` constraint
- `terminal1.acme.digital-donation.com`: donation terminal (`DonationsController`), via the `TerminalHost` constraint and `terminals.hostname`
- `acme.digital-donation.com`: login and owner dashboard (`Dashboard::*`), via `AccountScoped`

Session cookies are per host. `HandoversController` moves a user across hosts with a short-lived token, after signup and for impersonation. `TERMINAL_HOSTS=flat` switches new terminals to `terminal1-acme.digital-donation.com`.

### Payment providers

Everything provider-specific sits behind `PaymentProviders::Base` (`app/services/payment_providers/`). `Sumup` is the real one, `TestMode` simulates payments and is what every account starts with. To add a provider: subclass `Base`, register it in `PROVIDERS`, add its name and fields under `payment_providers` in `config/locales/app/*.yml`.

`PaymentConnection` holds an account's encrypted credentials. Never render them; `masked` exists for that. Each terminal belongs to one connection.

### Payment flow

1. `DonationsController#create` saves a `Donation`, whose `start_checkout!` starts the payment on the reader
2. The terminal polls `#status` every 5 seconds, which calls `sync_with_provider`
3. The provider also posts to `/webhooks/:provider/:webhook_token`

SumUp doesn't sign webhooks. The secret token identifies the account, and a success only counts once `sync_with_provider` has confirmed it with SumUp's API. `Donation#apply` takes a row lock, so polling and webhook can't send the confirmation email twice.

Donations through `TestMode` have `test: true` and never count in statistics (`Donation.live`).

### Tenancy rules

Always reach records through the account or terminal: `@account.terminals.find`, `@terminal.donations.find`. `test/integration/tenant_isolation_test.rb` covers this; add to it for every new tenant-owned resource.

### Frontend

Plain CSS through Sprockets, with tokens shared with Hutba: `marketing.css`, `app.css`, `admin.css` (builds on `app.css`) and `terminal.css`, which takes the account's colours as CSS variables from `layouts/terminal`. No Tailwind. esbuild bundles `app/javascript/*.js`: `application.js` for the terminal, `marketing.js`, `dashboard.js`.

Email goes through Postmark's API (`POSTMARK_API_KEY`, a server token, and `MAIL_FROM`).

Brand images live in the database (`BrandImage`) because Fly machines have no persistent disk.

### Internationalization

Locales: `de` (default), `bs`, `en`, in `config/locales/{marketing,app,terminal}/`. Every user-facing string needs all three. The super admin is English only.
