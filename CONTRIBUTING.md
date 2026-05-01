# Contributing

## Development setup

```bash
git clone https://github.com/openobserve/terraform-kubernetes-openobserve
cd terraform-kubernetes-openobserve
terraform init -backend=false
```

## Before every PR

```bash
# 1. Format
terraform fmt -recursive

# 2. Validate module and examples
terraform validate
terraform -chdir=examples/minimal validate
terraform -chdir=examples/complete validate

# 3. Lint
tflint --init
tflint
tflint --chdir=examples/minimal
tflint --chdir=examples/complete

# 4. Tests (no cluster needed — uses mock providers)
terraform test

# 5. Security
trivy config .
checkov -d . --framework terraform

# 6. Docs (regenerate README inputs/outputs table)
terraform-docs .
```

## Commit format

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) to drive automated versioning:

| Prefix | Version bump |
|--------|-------------|
| `feat!:` or `BREAKING CHANGE:` footer | Major |
| `feat:` | Minor |
| `fix:`, `perf:` | Patch |
| `docs:`, `chore:`, `refactor:` | No release |

PRs are squash-merged. The squash commit message must use the correct prefix.

## Release process

Releases are fully automated:

1. Merge a `feat:` or `fix:` PR to `main`
2. release-please opens a "Release PR" updating `CHANGELOG.md` and `version.txt`
3. Merge the Release PR — a git tag `vX.Y.Z` is created automatically
4. The Terraform Registry webhook detects the new tag and indexes the new version within minutes

**Never manually create or push version tags.** Let release-please manage them.

## Branch protection requirements (configure in GitHub settings)

- Require pull request before merging to `main`
- Require all status checks to pass: `fmt`, `validate`, `lint`, `security`, `test`, `docs`
- Require linear history (squash merge only)
- Restrict who can push to `main` (automation + org admins only)
- Do not allow force-pushes to `main`
