# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Rails 7 donation application for IGBN (Islamische Gemeinde Bosnien Nürnberg) that processes card payments via SumUp card readers. Donors select preset or custom amounts, and payments are processed through physical SumUp card terminals.

## Development Commands

```bash
# Start development server (runs Rails, JS bundler, and CSS bundler)
bin/dev

# Run tests
bin/rails test

# Run a single test file
bin/rails test test/models/donation_test.rb

# Run a specific test
bin/rails test test/models/donation_test.rb:10

# Database commands
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# Console
bin/rails console

# Build assets manually
yarn build           # JavaScript
yarn build:css       # Tailwind CSS
```

## Architecture

### Payment Flow

1. User selects amount on `home#index` (donation form)
2. `DonationsController#create` creates a `Donation` record and initiates a SumUp reader checkout via `SumupClient`
3. Frontend polls `DonationsController#status` every 5 seconds to check payment status
4. SumUp sends webhook to `SumupController#checkout_return_url` when transaction completes
5. On success, `DonationMailer` sends confirmation email if donor provided email

### Key Components

- **SumupClient** (`app/models/sumup_client.rb`): HTTP client for SumUp API v0.1. Handles reader checkouts, status checks, and reader status. Uses `SUMUP_API_KEY`, `SUMUP_MERCHANT_CODE`, and reader IDs from environment.

- **DonationsController**: Handles donation creation, status polling, and reader status checks. Reader ID can be set based on subdomain or params.

- **SumupController**: Webhook endpoint for SumUp transaction updates. Verifies webhook signatures using HMAC-SHA256.

- **Donation model**: States are `pending`, `processing`, `successful`, `failed`, `cancelled`. Sends confirmation email on status change to `successful`.

### Environment Variables

Required in `.env`:
- `SUMUP_API_KEY` - SumUp API bearer token
- `SUMUP_MERCHANT_CODE` - SumUp merchant identifier
- `SUMUP_READER1_ID` - Default card reader ID
- `APP_HOST` - Application hostname for webhook return URLs

Webhook secret stored in Rails credentials: `Rails.application.credentials.sumup[:webhook_secret]`

### Frontend

- **Hotwire**: Turbo and Stimulus for SPA-like behavior
- **Tailwind CSS 4**: Styling via `@tailwindcss/cli`
- **esbuild**: JavaScript bundling
- `app/javascript/donation.js`: Handles donation form interactions, payment initiation, status polling, and UI state transitions

### Internationalization

Locales: Bosnian (`bs`), German (`de`), English (`en`). Translation keys under `donations.index.*`.

### Database

PostgreSQL with a single `donations` table:
- `amount`, `currency`, `donor_name`, `donor_email`
- `status`, `checkout_reference`, `checkout_id`, `transaction_code`
