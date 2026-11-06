---
description: "Use when a task touches credentials — .env files, API keys, tokens, SSH keys, vault/sops/age files, auth configs — or you need to know whether a secret is present, set, or correct, or a command needs one as input."
mode: skill
---

# Handling secrets

The global rule: never read a secret value, never send one anywhere. This skill shows what to do instead. Almost every question about a secret can be answered without its value.

## Does it exist, and what's in it?

```sh
test -f .env && echo present
ls -l ~/.ssh/                                  # names, sizes, permissions
grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' .env       # key names only
grep -c '^API_KEY=' .env                       # is the key defined (count)
sops -d secrets.yaml | grep -oE '^ *[A-Za-z_]+:'   # vault structure, no values
ansible-vault view vault.yml | grep -oE '^ *[A-Za-z_]+:'
```

Decrypting is fine when the output is filtered down to names *in the same pipeline*. Never decrypt to a file or to your screen first.

## Is it set? Is it the right one?

```sh
[ -n "$TOKEN" ] && echo set
printf %s "$TOKEN" | wc -c                     # length: catches empty or truncated
printf %s "$TOKEN" | sha256sum | cut -c1-8     # fingerprint: compare two copies
```

To check that two hosts or files hold the same secret, compare fingerprints, not values.

Whether a credential *works* is best answered by the tool itself:

```sh
gh auth status
aws sts get-caller-identity
gcloud auth list
docker login --password-stdin <registry> < /path/to/file   # reports success or failure
ssh -o BatchMode=yes -T git@github.com
```

## A command needs the secret

Let the command read it; don't read it to paste it in.

```sh
set -a; . ./.env; set +a; ./run.sh             # env vars, never echoed
docker run --env-file .env image
curl -H @/path/to/header-file https://…        # header comes from a file
psql "$DATABASE_URL"                            # reference, unexpanded in your text
tool --password-file /run/secrets/x
```

Watch for commands that print their environment or arguments: `env`, `set -x`, `docker inspect`, `ps aux`, verbose curl (`-v`), debug logging. Don't run them where secrets are loaded, or filter their output to names.

## Searching code that might contain secrets

Search for *where* something is used, not what it contains:

```sh
rg -l 'API_KEY'                                # file names only
rg -n 'API_KEY' --glob '!.env*' --glob '!*.pem'
```

If a search might match a secret file, exclude it or use `-l`/`-c`.

## You genuinely need a value

Ask first. Name the file, the one key, and why the alternatives above don't work. Then read just that key, e.g. `grep '^ONE_KEY=' .env`, and never the whole file.

## A secret landed in your context anyway

Say so right away, and name the file and key. Don't repeat the value, don't write it anywhere, and don't keep working as if nothing happened: the user may need to rotate it.
