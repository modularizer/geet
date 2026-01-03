# Preventing App-Specific Code in Templates

## The Problem

When developing a template alongside your app, it's easy to accidentally commit app-specific code to the template repo:

- API keys and secrets
- Production configuration
- Customer-specific business logic
- "TODO: remove before template" comments
- Environment files

This pollutes the template and creates security risks.

## The Solution: Pattern-Based Prevention

geet includes a pre-commit hook that checks for configurable patterns before allowing commits to the template repo.

## Configuration

Patterns are defined in `.mytemplate/template-config.env` as pipe-delimited strings:

```bash
# Prevent committing files matching these patterns (pipe-delimited regex)
PREVENT_COMMIT_FILE_PATTERNS=".*\\.env.*|.*secret.*|.*\\.key$|config/production\\..*"

# Prevent committing content matching these patterns (pipe-delimited regex)
PREVENT_COMMIT_CONTENT_PATTERNS="API_KEY=|SECRET_KEY=|password:\\s*[\"'].*[\"']|TODO.*remove.*template|CUSTOMER_ID=|stripe_live_key"
```

### Pattern Types

**filePatterns** - Regular expressions matched against file paths:
- `.*\\.env.*` - Matches any .env file
- `.*secret.*` - Matches files with "secret" in name
- `config/production\\.json` - Specific file path

**contentPatterns** - Regular expressions matched against file contents:
- `API_KEY=` - Literal string match
- `password:\\s*[\"'].*[\"']` - Password with quotes
- `TODO.*remove.*template` - Reminder comments
- Case-sensitive by default

## How It Works

**On every `geet commit`:**

1. Pre-commit hook reads patterns from config
2. Checks each staged file against `filePatterns`
3. Checks content of each staged file against `contentPatterns`
4. If matches found, **blocks the commit** with helpful error

**Example error:**

```
❌ [pre-commit] Found patterns that may indicate app-specific code:

  FILE: config/production.json matches pattern: config/production\..*
  CONTENT: src/auth.ts:45 matches pattern: API_KEY=
  → 45:const apiKey = process.env.API_KEY="sk-live-1234567890"
  CONTENT: src/db.ts:12 matches pattern: password:\s*["'].*["']
  → 12:  password: 'my-secret-pass'

These patterns suggest implementation-specific code that shouldn't be in the template.

To bypass this check: git commit --no-verify
To fix: Remove the matched patterns or update .mytemplate/.geet-template.env
```

## Bypassing the Check

If you're certain the code should be committed:

```bash
geet commit --no-verify -m "Add intentional example"
```

**Use sparingly!** The patterns exist for a reason.

## Common Patterns

### Security-related

```json
{
  "filePatterns": [
    ".*\\.env.*",
    ".*\\.pem$",
    ".*\\.key$",
    ".*secret.*",
    ".*credential.*"
  ],
  "contentPatterns": [
    "API_KEY=",
    "SECRET_KEY=",
    "PRIVATE_KEY=",
    "password:\\s*[\"'].*[\"']",
    "Bearer\\s+[A-Za-z0-9\\-_]+",
    "sk-[A-Za-z0-9]+"
  ]
}
```

### App-specific configuration

```json
{
  "filePatterns": [
    "config/(production|staging)\\..*"
  ],
  "contentPatterns": [
    "DATABASE_URL=.*production.*",
    "STRIPE_LIVE_KEY=",
    "CUSTOMER_ID=",
    "TENANT_ID="
  ]
}
```

### Development reminders

```json
{
  "contentPatterns": [
    "TODO.*remove.*template",
    "FIXME.*before.*publish",
    "HACK.*replace",
    "XXX.*app.?specific"
  ]
}
```

### Business logic markers

```json
{
  "contentPatterns": [
    "// Customer-specific",
    "// ACME Corp only",
    "// This is specific to",
    "@internal"
  ]
}
```

## Regular Expression Tips

**Escape special characters:**
- `.` → `\\.` (literal dot)
- `*` → `\\*` (literal asterisk)
- `[` → `\\[` (literal bracket)

**Common patterns:**
- `.*` - Any characters
- `\\s+` - One or more spaces
- `[\"']` - Single or double quote
- `(foo|bar)` - Foo OR bar
- `^start` - Line starts with
- `end$` - Line ends with

**Case-insensitive matching:**

Use `(?i)` prefix:
```json
"contentPatterns": [
  "(?i)api.?key",
  "(?i)password"
]
```

## Disabling the Check

**Temporarily:**
```bash
geet commit --no-verify
```

**Permanently for a template:**

Remove the `preventCommit` section from `geet-config.json`:

```json
{
  "name": "mytemplate",
  "desc": "My template"
  // preventCommit section removed
}
```

**For specific files:**

Add to `.geetinclude` only what should be in the template.
The hook only checks staged files.

## Limitations

- Requires `jq` to be installed (gracefully skips if missing)
- Only checks text files (skips binaries)
- Regex can have false positives (use `--no-verify` when needed)
- Can't detect all app-specific logic (some requires human judgment)

## Best Practices

1. **Start strict, relax as needed**
   - Begin with conservative patterns
   - Add `--no-verify` exceptions when justified

2. **Document your patterns**
   - Add comments in geet-config.json explaining why each pattern exists

3. **Review regularly**
   - Update patterns as you discover new app-specific markers
   - Remove patterns that cause too many false positives

4. **Combine with code review**
   - Patterns catch obvious mistakes
   - Human review catches subtle app-specific logic

5. **Use descriptive pattern names**
   ```json
   "contentPatterns": [
     "API_KEY=",           // Catch hardcoded API keys
     "TODO.*remove",       // Catch developer reminders
     "STRIPE_LIVE_KEY="    // Production payment keys
   ]
   ```
   *(Note: JSON doesn't support comments, but you can document in README)*

## Related Documentation

- [File promotion](/docs/AUTO_PROMOTE.md) - Auto-promote README and other files
- [Publishing a template](/docs/PUBLISHING_A_TEMPLATE.md) - Template publishing workflow
- [Multi-layered repos](/docs/MULTI_LAYERED_TEMPLATES.md) - Managing multiple templates

## Summary

The preventCommit patterns are a **safety net**, not a security guarantee:

✅ **Good for:**
- Catching accidental commits of secrets
- Enforcing team conventions
- Preventing obvious mistakes

❌ **Not a substitute for:**
- Proper secret management
- Code review
- Security audits
- Developer training

Use it as one layer in a defense-in-depth strategy for keeping templates clean and generic.
