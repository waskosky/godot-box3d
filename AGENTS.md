# Contributor and Agent Guidance

## Downstream baseline

- `main` is this fork's reviewed downstream baseline; `integration/next` carries advancing experiments. Promote validated snapshots without rewriting shared history and carry baseline fixes/documentation into the integration feed.
- Keep the fork README explicit about upstream attribution, static embedding, worker-main motivation, host responsibilities, and the limits of the recorded validation.
- Validate a new static host module/template with the existing browser physics smoke scene. Archive-only checks and ordinary dynamic-extension CI do not qualify the static profile.
- Keep the example host module generic. Private consumer code, identifiers, and deployment configuration do not belong in public changes.

## Upstream pull requests

- Base every upstream pull request directly on the current `bearlikelion/godot-box3d` `main` branch. Do not use `integration/next` as an upstream pull request base.
- Keep each pull request independent and focused on one coherent physics behavior, platform capability, or supporting infrastructure change.
- Include focused regression coverage for the behavior being changed. Avoid unrelated test expansion and keep validation proportional to the change.
- Keep no more than six ready-for-review upstream pull requests open at once.
- Deliver larger efforts as a small sequence of independently reviewable changes instead of one broad combined diff.
- Treat `integration/next` as the downstream experiment and validation feed. It may combine validated work, but its unrelated history must not leak into upstream pull requests.
- Before publishing, start from the latest upstream `main`, inspect the complete diff, and run the most relevant local checks.
- Ordinary upstream Web support should use official Godot templates and the existing CMake build where practical.
- Keep static embedding, host patches, custom template production, and extended browser qualification downstream unless the maintainer requests them.
- Do not identify private consumers or expose their code, repository names, deployment details, or links in public changes and discussions.
