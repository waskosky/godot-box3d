# Contributor and Agent Guidance

## Upstream pull requests

- Base every upstream pull request directly on the current `bearlikelion/godot-box3d` `main` branch. Do not use `integration/next` as an upstream pull request base.
- Keep each pull request independent and focused on one coherent physics behavior, platform capability, or supporting infrastructure change.
- Include focused regression coverage for the behavior being changed. Avoid unrelated test expansion and keep validation proportional to the change.
- Keep no more than three ready-for-review upstream pull requests open at once.
- Deliver larger efforts as a small sequence of independently reviewable changes instead of one broad combined diff.
- Treat `integration/next` as the downstream experiment and validation feed. It may combine validated work, but its unrelated history must not leak into upstream pull requests.
- Before publishing, start from the latest upstream `main`, inspect the complete diff, and run the most relevant local checks.
