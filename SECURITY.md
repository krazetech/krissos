# Security policy

Thank you for helping keep KrissOS and the people who use it safe.

## Reporting a vulnerability

**Please do not report security problems in a public issue, pull request or discussion.**

Report them privately through GitHub instead:

1. Open the [Security tab](https://github.com/krazetech/krissos/security) of this repository.
2. Choose **Report a vulnerability**.
3. Fill in the form. Only the maintainers can see it.

Or go straight to the form at
<https://github.com/krazetech/krissos/security/advisories/new>.

You can write in English or Bahasa Melayu.

### What to include

- What the problem is and what an attacker could do with it.
- The steps to reproduce it, or a proof of concept.
- What it affects: the package, tool, ISO or workflow, and its version. On an installed
  system, `kriss version` prints the KrissOS and `kriss` versions.
- Whether it is already public or being exploited, as far as you know.
- How you would like to be credited, if at all.

## What happens next

KrissOS is kept alive by one or two maintainers, so these are honest targets, not a paid
service level:

| Step | Target |
|---|---|
| We confirm we got your report | Within 7 days |
| We tell you whether we accept it and how serious we think it is | Within 14 days |
| A fix ships for a critical or high severity issue | Within 30 days |
| A fix ships for anything else | Within 90 days |

We will keep you updated in the private advisory, and agree a disclosure date with you. When a
fix ships we publish a GitHub security advisory, request a CVE where it fits, and credit you
unless you ask us not to. Please give us the time above before you disclose the issue
publicly.

## Supported versions

KrissOS is a rolling release. Fixes ship as updated packages in the `[kriss]` repository, so a
system that is kept up to date with `kriss update` gets them. We do not patch old ISO images.
The next ISO picks up the fix.

| Version | Supported |
|---|---|
| Installed systems updating from the `[kriss]` repo | Yes |
| The latest ISO release (currently `0.1-alpha`, a preview) | Yes. Install, then update |
| The rolling `preview` ISO | Best effort |
| Older ISO releases | No. Download the latest one |
| Apple Silicon image (`aarch64`) | Best effort while it is in preview |

## Scope

**In scope.** Anything this repository builds or ships:

- The `[kriss]` packages in `pkgs/` and the tools in `tools/`, such as `kriss`, `kriss-migrate`
  and `kriss-update-notify`.
- The installer (`installer/`), the live image (`iso/`) and the defaults they set up, such as
  users, passwords, disk encryption, Secure Boot and polkit rules.
- The shell, `kriss-welcome` and the theme.
- Our build and release pipeline in `.github/workflows/`, including package and ISO signing.
- The website at <https://krazetech.github.io/krissos/>.

**Report upstream instead.** Most of a KrissOS system is unchanged Arch Linux. Problems in
packages that come straight from Arch belong with the
[Arch Linux security team](https://security.archlinux.org/), and problems in a program itself
belong with that program's developers. If you are not sure where something belongs, report it
to us and we will pass it on.

**Not in scope.** Problems that need someone to already have root or physical access to an
unlocked machine, social engineering, and reports from automated scanners with no shown
impact.

## Signing key

Packages, ISOs and checksums are signed by `KrissOS Packages`, fingerprint
`7C92AE8B599AF81321666CA31317AA31B21C5F87`. Never trust a download whose signature does not
check out against that key. See [Verify your download](README.md#verify-your-download).

If you think the signing key or the release pipeline has been compromised, report it as
above and mark it critical. If the key is ever replaced or revoked, we will announce it in a
security advisory, in the README and through an update to the `kriss-keyring` package.
