# Contributing to visi-wazuh-agents

First off, thank you for taking the time to contribute. This project is maintained by the **Vaquero Information Security Initiative (VISI)**, a student-run cybersecurity nonprofit at UTRGV serving the Rio Grande Valley community. Every contribution helps us build better open-source security tooling for under-resourced organizations.

You can find our website [here](https://vaqueroisi.org/).

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Commit Message Convention](#commit-message-convention)
- [Versioning](#versioning)
- [Security Vulnerabilities](#security-vulnerabilities)

---

## Code of Conduct

This project follows a simple rule: be respectful. We are a community-oriented project rooted in the RGV and we welcome contributors of all backgrounds and skill levels. Harassment, gatekeeping, or dismissive behavior toward contributors — especially students and newcomers — will not be tolerated.

---

## Getting Started

### Prerequisites

Make sure you have the following installed before contributing:

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6.0
- [TFLint](https://github.com/terraform-linters/tflint) for linting
- [terraform-docs](https://terraform-docs.io/) for documentation generation
- An AWS account for testing (free tier is sufficient for most changes)
- A [Tailscale](https://tailscale.com/) account (free tier works)

### Fork and Clone

```bash
git clone https://github.com/dsuyu1/visi-wazuh-agents.git
cd visi-wazuh-agents
```

---

## How to Contribute

### Reporting Bugs

Before opening a bug report, please search existing issues to avoid duplicates. When filing a bug, include:

- Your Terraform version (`terraform version`)
- Your AWS region
- Your Wazuh manager version
- The full error output
- Steps to reproduce

Use the **Bug Report** issue template.

### Suggesting Features

Open a **Feature Request** issue describing:

- The problem you're trying to solve
- Your proposed solution
- Any alternatives you considered

### Contributing Code

Good first issues are labeled `good first issue`. These are intentionally scoped to be approachable for new contributors.

Areas where contributions are especially welcome:

- Support for additional Linux distros in `install_agent.sh.tpl` (currently Ubuntu/Debian only)
- Windows agent support
- GCP and Azure agent variants
- Improved logging and error handling in the install script
- Additional Terraform outputs
- Test coverage

---

## Development Setup

### 1. Copy the example tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your own values. **Never commit this file** — it is in `.gitignore` for a reason.

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Validate your changes

Before opening a PR, always run:

```bash
# Format
terraform fmt -recursive

# Validate
terraform validate

# Lint
tflint --init
tflint
```

All three must pass cleanly. The CI pipeline will enforce this on every PR.

### 4. Test your changes

If your change modifies infrastructure behavior (not just docs or variables), test it end-to-end:

```bash
terraform plan
terraform apply
# Verify agents enrolled in your Wazuh manager
terraform destroy
```

---

## Pull Request Process

1. **Branch off `main`** — use a descriptive branch name:
   ```bash
   git checkout -b feat/windows-agent-support
   git checkout -b fix/authd-timeout-handling
   git checkout -b docs/update-tailscale-setup
   ```

2. **Make your changes** — keep PRs focused. One logical change per PR.

3. **Run all checks locally** before pushing:
   ```bash
   terraform fmt -recursive
   terraform validate
   tflint
   ```

4. **Write a clear PR description** explaining what changed and why. Reference any related issues with `Closes #123`.

5. **Request a review** — at least one maintainer approval is required before merging.

6. **Do not merge your own PR** unless you are a maintainer and the CI is green.

### What Makes a Good PR

- Small and focused — easier to review and less likely to introduce bugs
- Includes updates to `README.md` if you added or changed variables
- Does not break existing behavior without a clear reason
- Does not introduce hardcoded values that should be variables

---

## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Types:**

| Type | When to use |
|---|---|
| `feat` | New feature or variable |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code restructure, no behavior change |
| `chore` | Dependency updates, CI changes |
| `security` | Security-related fix |

**Examples:**

```
feat(template): add support for Amazon Linux 2023
fix(tailscale): handle auth key expiry gracefully
docs(readme): add GCP setup instructions
chore(ci): upgrade terraform-docs action to v1.1
```

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/):

- **PATCH** (`v1.0.1`) — backwards-compatible bug fixes
- **MINOR** (`v1.1.0`) — new backwards-compatible features
- **MAJOR** (`v2.0.0`) — breaking changes (renamed variables, removed resources, changed behavior)

Releases are tagged on `main` by maintainers after PRs are merged. If your contribution warrants a release, mention it in your PR description.

---

## Security Vulnerabilities

**Do not open a public GitHub issue for security vulnerabilities.**

If you discover a security issue in this module — especially anything related to credential handling, IAM permissions, or network exposure — please report it privately by emailing the VISI team directly. We will acknowledge your report within 48 hours and work with you on a fix before any public disclosure.

---

## Questions?

If you're unsure about anything, open a **Discussion** on GitHub rather than an issue. We're happy to help contributors at any level get started.

— The VISI Team | University of Texas Rio Grande Valley