# Redmine CSAT MVP 0.1.0

Standalone one-click customer satisfaction plugin targeting Redmine 6.1.2.

## Features

- Dispatches on transition into configured issue statuses.
- Enabled per project through the `Customer satisfaction` project module.
- Resolves the customer from a configured Redmine Customer role, then falls back to an issue custom field such as `owner-email`.
- Uses normalised email suppression with a configurable cooldown, default 14 days.
- Records the first Poor, OK or Great link selection immediately.
- Accepts an optional comment after the rating is recorded.
- Includes project-level CSAT and response-rate reporting.
- Can create a separate follow-up issue for Poor feedback.
- Stores a SHA-256 digest rather than the raw survey token.

## Install

Copy this directory to `REDMINE_ROOT/plugins/redmine_csat`, then run:

```bash
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart Redmine.

## Configure

1. Open **Administration > Plugins > Redmine CSAT > Configure**.
2. Choose the Customer role.
3. Choose the fallback issue custom field, normally `owner-email`.
4. Select one or more trigger statuses, normally Closed.
5. Set the cooldown in days.
6. In each eligible project, enable **Customer satisfaction** under **Settings > Modules**.
7. Grant internal roles the **View CSAT reports** permission.
8. Verify Redmine's **Host name and path** and **Protocol** settings because they are used in public survey links.

## Recipient rules

1. Look for a directly related active Redmine user with the configured Customer role. The issue author is preferred where several directly related customer users exist.
2. If no unambiguous customer user is found, use the selected issue custom field.
3. If no valid email is available, skip the request.
4. Cooldown is checked against the normalised email regardless of its source.

The plugin does not survey every customer-role member of a project.

## Test checklist

- Customer-role issue author receives one request after a configured status transition.
- An issue with no matching user uses `owner-email`.
- Another issue for the same email during cooldown is suppressed.
- A rating is recorded on the first link selection.
- A later selection does not replace that first response.
- Optional comment saves successfully.
- Poor feedback creates a follow-up only when configured.
- Users without the report permission cannot access the project report.

## Production note

Install and validate in staging first. Email is sent synchronously after the issue transaction commits. If your production Redmine uses a validated Active Job backend, change `deliver_now` in `SurveyDispatcher` to `deliver_later`.

## Uninstall

Back up the database, then run:

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_csat VERSION=0 RAILS_ENV=production
```
