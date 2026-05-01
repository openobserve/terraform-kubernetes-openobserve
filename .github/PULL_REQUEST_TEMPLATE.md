## Description

<!-- What does this PR do? Link to any related issues. -->

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behaviour)
- [ ] Documentation update

## Checklist

### Required for all PRs

- [ ] `terraform fmt -recursive` has been run
- [ ] `terraform validate` passes for root module and all examples
- [ ] `terraform test` passes (run locally with `terraform init && terraform test`)
- [ ] Variable descriptions are clear; new variables have `validation` blocks where appropriate
- [ ] Sensitive variables are marked `sensitive = true`

### Required for feature / breaking changes

- [ ] `examples/minimal` and/or `examples/complete` updated to demonstrate the change
- [ ] README updated (run `terraform-docs .` to regenerate the inputs/outputs tables)
- [ ] Tests added or updated in `tests/`
- [ ] CHANGELOG entry added under `## [Unreleased]` (release-please will promote it)

### Required for breaking changes

- [ ] Existing behaviour documented in the description above
- [ ] Migration path described (what callers need to change)
- [ ] Commit message uses `feat!:` or includes `BREAKING CHANGE:` footer so release-please bumps the major version

## Conventional commit guidance

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) to drive automated releases:

| Prefix | Effect |
|--------|--------|
| `feat!:` or `BREAKING CHANGE:` footer | Major version bump |
| `feat:` | Minor version bump |
| `fix:` | Patch version bump |
| `docs:`, `chore:`, `refactor:` | No release |

Use the correct prefix in the **first commit message on this PR** (squash merge is recommended).
