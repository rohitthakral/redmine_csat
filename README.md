# Redmine CSAT

Customer satisfaction (CSAT) surveys for Redmine issues. When an issue moves
into a status you choose (normally *Closed*), the customer gets a short email
asking how their experience was: **Great**, **OK** or **Poor**. Answers appear
in a per-project report, and Poor answers can open a follow-up issue
automatically.

- **Version:** 0.2.0
- **Requires:** Redmine 6.1.2 or later (Rails 7.2, Ruby 3.2+)
- **Licence:** see `LICENSE`

## Contents

1. [How it works](#how-it-works)
2. [Installation](#installation)
3. [Upgrading from 0.1.0](#upgrading-from-010)
4. [Configuration](#configuration)
5. [Customising the survey email](#customising-the-survey-email)
6. [Who receives the survey](#who-receives-the-survey)
7. [The project report](#the-project-report)
8. [Data retention and privacy](#data-retention-and-privacy)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)
11. [Uninstalling](#uninstalling)

## How it works

1. An issue changes into one of the configured **trigger statuses**.
2. The plugin finds the customer (see [Who receives the survey](#who-receives-the-survey))
   and checks that this is allowed: the module is enabled, there is no earlier
   survey for this issue, the issue is old enough, and the email address is
   not in its cooldown period.
3. One email is sent with three buttons: Great, OK and Poor. Each button is a
   unique link. Only a SHA-256 digest of the link token is stored.
4. Clicking a button opens a page with that rating pre-selected and an optional
   comment box. **The rating is recorded when the customer presses Submit.**
   Opening the link alone records nothing. This matters because email security
   scanners (Microsoft Defender Safe Links, Mimecast, Proofpoint and others)
   open every link in a message before the recipient sees it.
5. The customer can change the rating or comment for a limited time (24 hours
   by default). After that, the answer is locked.
6. If enabled, a **Poor** rating creates one private follow-up issue. Later
   changes to the rating or comment are added to that issue as notes. No
   further issues are created.

Each issue is surveyed at most once, even if it is reopened and closed again.

## Installation

### 1. Get the code

Put the plugin in Redmine's `plugins` directory. The directory **must** be
named `redmine_csat`.

```bash
cd /path/to/redmine/plugins
```

```bash
git clone https://github.com/rohitthakral/redmine_csat.git redmine_csat
```

Or copy or unpack a release into `/path/to/redmine/plugins/redmine_csat`.

### 2. Run the database migrations

From the Redmine root directory:

```bash
cd /path/to/redmine
```

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_csat RAILS_ENV=production
```

The plugin has no extra gem dependencies, so `bundle install` is not needed.

### 3. Restart Redmine

Restart the application server (Puma, Passenger, Unicorn and so on), for example:

```bash
touch tmp/restart.txt
```

### 4. Check the installation

Go to **Administration → Plugins**. *Redmine CSAT* should be listed with
version 0.2.0 and a **Configure** link.

### 5. Check Redmine's email and URL settings

The survey uses Redmine's normal email delivery (`config/configuration.yml`)
and builds links from Redmine's own settings. Under **Administration →
Settings → General**, check:

- **Host name and path**, for example `support.example.com` or
  `example.com/redmine`. Sub-path installs are supported.
- **Protocol**: `https` in production.

If these are wrong, the links in survey emails will not work.

## Upgrading from 0.1.0

0.2.0 adds a migration and changes the survey links. To upgrade:

1. Back up the database.
2. Replace the plugin directory with the new version.
3. Run the migration:

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_csat RAILS_ENV=production
```

4. Restart Redmine.
5. Open **Administration → Plugins → Redmine CSAT → Configure**, review the
   new settings, and press **Apply** once to save them.

The migration:

- marks existing surveys as delivered;
- removes survey rows for issues that no longer exist;
- removes duplicate surveys for the same issue (keeping the one with an answer,
  or the oldest);
- enforces one survey per issue in the database.

Links in emails already sent keep working. They now show the confirmation
page instead of recording the vote straight away.

**Note:** in 0.1.0 the issue hook was registered in a way that does not run
when Redmine 6 boots in production, so 0.1.0 may never have sent a survey.
0.2.0 fixes this.

## Configuration

There are four steps: global settings, per-project module, permissions, and
optionally the customer role and custom field.

### Step 1: Prepare how customers are identified

Use one or both of these:

- **Customer role (recommended when customers log in to Redmine).** Create a
  role under **Administration → Roles and permissions**, for example
  *Customer*, and add your customer users to projects with that role.
- **Owner-email custom field (for customers without Redmine accounts).**
  Create an issue custom field under **Administration → Custom fields → New
  custom field → Issues**:
  - Format: *Text* (or *Link*)
  - Name: for example `owner-email`
  - Trackers and projects: wherever it is needed

  Fill in the customer's address on each issue. If the field holds several
  addresses (separated by commas, semicolons or spaces), the first valid one
  is used.

### Step 2: Global settings

Go to **Administration → Plugins → Redmine CSAT → Configure**.

**General**

| Setting | Default | What it does |
| --- | --- | --- |
| Enable CSAT | on | Master switch. When off, nothing is sent and survey links stop working. |
| Trigger statuses | none | Statuses that send a survey when an issue moves into them. Usually *Closed* and/or *Resolved*. **No survey is sent until at least one is selected.** |
| Minimum issue age in hours | 0 | Skip issues created less than this many hours ago (for example quick spam or duplicates). |
| Send emails in the background | off | Uses `deliver_later`. Only enable this if Redmine has a reliable Active Job backend (Sidekiq, GoodJob and so on). Redmine's default in-process queue loses jobs on restart. |

**Recipients**

| Setting | Default | What it does |
| --- | --- | --- |
| Customer role | none | The role that identifies customers. |
| Fallback owner-email issue field | none | Issue custom field used when no customer user is found. |
| Minimum days between surveys to the same email | 14 | One address receives at most one survey in this period, whichever issue it came from. 0 turns this off. |

**Survey email**

| Setting | Default | What it does |
| --- | --- | --- |
| Email subject | `How did we do? Request #{{issue_id}}` | Any [placeholder](#customising-the-survey-email) can be used. The 0.1.0 syntax (`%{issue_id}`, with `%%` for a percent sign) still works. |
| Sender address | Redmine's *Emission email address* | `From:` address for survey emails. |
| Company name | Redmine's *Application title* | Shown at the top of the email (when there is no logo) and in the default text. |
| Logo URL | none | A public `https://` image, shown 40 pixels high. |
| Brand colour | `#2f6fb5` | Colour of the top border and the company name. |
| Rating prompt | `How was your experience with us?` | Heading in the email and on the survey page. |
| Rating labels | Great / OK / Poor | Button labels. |
| Introduction text | built-in text | Plain text with placeholders. Leave empty for the default. |
| Footer text | built-in text | Plain text with placeholders. Leave empty for the default. |
| Show the request details | on | Shows a box with the request number, subject, project and agent. |
| Custom HTML / plain-text template | empty | Replaces the whole email. See [Customising the survey email](#customising-the-survey-email). |

The **Preview email** and **Send a test email** buttons at the bottom of this
section use the values in the form, including changes you haven't saved yet.

**Survey page**

| Setting | Default | What it does |
| --- | --- | --- |
| Allow optional comments | on | Shows a comment box on the survey page. |
| Submit the rating automatically | off | Submits the form with JavaScript as soon as the page opens. This saves the customer one click, but some security scanners run JavaScript and could submit false ratings. Leave it off unless you have checked this with your customers' mail systems. |
| Hours the customer can change their answer | 24 | After this, the answer is locked. 0 locks it immediately. |
| Days a survey link stays valid | 60 | Unanswered links stop working after this. Answered surveys can still be viewed. 0 means links never expire. |

**Follow-up issues for Poor ratings**

| Setting | Default | What it does |
| --- | --- | --- |
| Create a follow-up issue for Poor | off | Creates one issue per Poor answer. It is linked to the rated issue with a *related to* relation when cross-project relations allow it. |
| Follow-up project | same project | Use a separate internal project (for example *Customer success*) so customers never see follow-ups. |
| Follow-up tracker | same tracker | Used when enabled in the follow-up project; otherwise the rated issue's tracker, then the project's first tracker. |
| Follow-up assignee | none | Must be assignable in the follow-up project. If not, the issue is created unassigned and a warning is logged. |
| Follow-up author | assignee of the rated issue, else the first administrator | User shown as the author of follow-ups and their notes. |
| Make follow-up issues private | on | Recommended when follow-ups go into the customer's own project. |

Follow-up issues are never surveyed themselves. If one cannot be created (for
example because of a required custom field or a missing tracker), the reason
is logged and shown in the project report.

**Data retention**

| Setting | Default | What it does |
| --- | --- | --- |
| Days to keep hashed IP addresses | 90 | After this, the hashed IP address is cleared from answers. 0 keeps it. |
| Days to keep survey data | 0 (forever) | Surveys and answers older than this are deleted. |

Retention is applied by a rake task. See [Data retention and privacy](#data-retention-and-privacy).

### Step 3: Enable the module in each project

In each project that should send surveys, go to **Project → Settings →
Modules**, tick **Customer satisfaction** and save. Subprojects need it
enabled separately.

### Step 4: Grant the report permission

Under **Administration → Roles and permissions**, give **View CSAT reports**
to the internal roles that should see results (for example *Manager*). Do
**not** give it to the customer role: the report shows customer names, email
addresses and comments.

### Quick test

To check the email design first, use **Preview email** or **Send a test
email** on the settings page. Then run an end-to-end test:

1. Create a test issue in an enabled project. Make yourself (with a test
   email address) the author with the customer role, or fill in the
   owner-email field.
2. Move the issue to a trigger status.
3. Check that the email arrives. Click a button, add a comment and press
   **Submit**.
4. Open **Customer satisfaction** in the project menu and check that the
   answer appears.

## Customising the survey email

The built-in email has your company name or logo at the top, a greeting, a
short introduction, a box with the request details, and three large buttons
(Great, OK, Poor). The buttons sit side by side on a computer and stack on a
phone. A plain-text version is always sent alongside the HTML. Emails are
written in the customer's Redmine language, or in Redmine's default language
for recipients who aren't Redmine users.

There are three levels of customisation, all under **Administration →
Plugins → Redmine CSAT → Configure → Survey email**.

### 1. Simple settings

Set the company name, logo URL, brand colour, prompt, button labels,
introduction and footer. The introduction and footer are plain text: HTML tags
are shown as typed, a blank line starts a new paragraph, and placeholders such
as `{{customer_name}}` or `{{issue_subject}}` can be used.

### 2. Custom templates

Open **Custom templates (advanced)** and click **Insert the built-in
template** to start from the default design. Then edit it. You can provide an
HTML template, a plain-text template, or both. Any template left empty uses the
built-in design.

Rules:

- Values go in with `{{placeholder}}` tags. They are HTML-escaped
  automatically, so issue subjects and names can't break the layout or inject
  HTML.
- Templates are not ERB or Liquid. They can't run code or include logic.
- A template **must** contain `{{rating_buttons}}`, or at least one of
  `{{great_url}}`, `{{okay_url}}` and `{{poor_url}}`. Otherwise it is ignored,
  the built-in template is used, and the preview shows a warning.
- Unknown placeholders are left in the email as typed, and the preview lists
  them.
- Use inline styles and table layouts. Many email apps (Outlook, Gmail)
  ignore `<style>` blocks and modern CSS.

### 3. Preview and test

- **Preview email** opens a new tab showing the email at desktop and mobile
  widths with example data, plus the plain-text version and any template
  warnings.
- **Send a test email** sends the example email to your own address. The
  rating buttons in a test email aren't connected to a real survey.

Both use the values in the form, so you can try changes before saving them.

### Placeholders

| Placeholder | Value |
| --- | --- |
| `{{greeting}}` | "Hi *name*," or "Hello," when the name is unknown |
| `{{customer_name}}` | Customer's name (empty for owner-email recipients) |
| `{{issue_id}}`, `{{issue_subject}}`, `{{project}}`, `{{status}}` | Details of the rated issue |
| `{{issue_url}}` | Link to the issue (only for customers who are Redmine users) |
| `{{agent_name}}` | User who made the status change, or the assignee |
| `{{company_name}}`, `{{logo_url}}`, `{{brand_color}}` | Design settings |
| `{{prompt}}`, `{{great_label}}`, `{{okay_label}}`, `{{poor_label}}` | Prompt and button labels |
| `{{great_url}}`, `{{okay_url}}`, `{{poor_url}}` | The three rating links |
| `{{expiry_date}}`, `{{expiry_notice}}` | When the link expires (empty if links never expire) |
| `{{subject}}`, `{{preheader}}`, `{{hint}}` | Email subject, inbox preview line, instruction under the buttons |
| `{{intro}}`, `{{footer}}` | Introduction and footer as plain text |

Ready-made blocks: in HTML templates they are inserted as HTML, in
plain-text templates as text.

| Block | Content |
| --- | --- |
| `{{header}}` | Logo, or the company name |
| `{{intro_html}}`, `{{footer_html}}` | Introduction and footer as HTML paragraphs |
| `{{issue_details}}` | Request details box (empty if turned off) |
| `{{rating_buttons}}` | The three buttons (one link per line in plain text) |

The built-in templates are in `config/email_templates/` if you want to read
them outside Redmine.

## Who receives the survey

1. Users directly related to the issue are checked: the author, the assignee
   and watchers. Only active users who have the configured customer role in
   the issue's project count.
   - If exactly one matches, they receive the survey.
   - If several match and the author is one of them, the author receives it.
   - Otherwise, no customer user is chosen.
2. If no customer user is chosen, the owner-email custom field is used.
3. If neither gives a valid address, no survey is sent.
4. The cooldown is checked against the normalised (lower-cased) address,
   wherever it came from.

The plugin never surveys every customer-role member of a project.

Emails are sent in the recipient's Redmine language when they are a Redmine
user, otherwise in Redmine's default language. Text you enter in the settings
(prompt, labels, introduction, footer, templates) is used as typed, in every
language.

## The project report

Open **Customer satisfaction** in the project menu. It needs the *View CSAT
reports* permission.

- **CSAT score:** the percentage of answers rated *Great*.
- **Response rate:** answers divided by surveys delivered.
- **Filters:** the *From* and *To* dates filter on when the survey was sent,
  so the score and response rate describe the same surveys. You can also
  include subprojects.
- Only issues the current user can see are included, so private issues stay
  private.
- Follow-up issues are linked. Failed follow-ups are flagged; hover over the
  flag to see the reason.
- **CSV export:** use the *CSV* link at the bottom of the report.

## Data retention and privacy

- Survey links contain a random 256-bit token. Only its SHA-256 digest is
  stored.
- An HMAC of the respondent's IP address (keyed with Redmine's secret key) is
  stored to help spot abuse. This still counts as personal data under GDPR.
- Customer emails and comments are visible to anyone with *View CSAT
  reports*.
- With background delivery on, the raw token sits in the job queue until the
  email is sent.

To apply the retention settings, run this regularly (for example nightly from cron):

```bash
cd /path/to/redmine && bundle exec rake redmine_csat:purge RAILS_ENV=production
```

Example crontab entry:

```bash
15 3 * * * cd /path/to/redmine && bundle exec rake redmine_csat:purge RAILS_ENV=production >> log/redmine_csat_purge.log 2>&1
```

## Testing

The tests use Redmine's own test setup and fixtures. From the Redmine root:

```bash
RAILS_ENV=test bundle exec rake db:create db:migrate redmine:plugins:migrate
```

```bash
bundle exec rake redmine:plugins:test NAME=redmine_csat
```

## Troubleshooting

**No survey email is sent.** Check `log/production.log` for lines starting
with `[redmine_csat]`. Then check that:

- the plugin is enabled and at least one trigger status is selected;
- the project has the *Customer satisfaction* module enabled;
- the issue really changed into the trigger status (editing an issue that is
  already closed does not count);
- the issue has not been surveyed before;
- a customer can be found (customer role or owner-email field);
- the address is not in its cooldown period;
- Redmine can send email at all (**Administration → Settings → Email
  notifications → Send a test email**).

**My custom template isn't used.** Open **Preview email**. If the template
has no rating links, the warning at the top says so, and the built-in template
is used instead.

**The email looks different in Outlook or Gmail.** These apps ignore much
modern CSS. Start from the built-in template, which uses tables and inline
styles that work in them, and test with **Send a test email**.

**Links in the email point to the wrong host.** Fix **Host name and path**
and **Protocol** under **Administration → Settings → General**.

**Every answer is Poor, or answers appear that nobody gave.** Check that
*Submit the rating automatically* is off.

**A follow-up was not created.** Hover over *Failed* in the report, or search
the log for `follow-up`. The usual causes are:

- a required custom field on the follow-up tracker;
- the tracker is not enabled in the follow-up project;
- no default issue priority is set.

**A send failed.** If the email fails during a synchronous send, the survey
record is removed. The issue is surveyed the next time it reaches a trigger
status, and the cooldown is not used up. A background send that is still
unconfirmed after one hour is treated the same way.

## Uninstalling

1. Back up the database.
2. Remove the plugin's tables:

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_csat VERSION=0 RAILS_ENV=production
```

3. Delete `plugins/redmine_csat`.
4. Restart Redmine.
