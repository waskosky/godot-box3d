# godot-box3d-embedded

This is [waskosky's downstream fork](https://github.com/waskosky/godot-box3d-embedded) of [bearlikelion/godot-box3d](https://github.com/bearlikelion/godot-box3d). It integrates [Erin Catto's Box3D](https://github.com/erincatto/box3d) with Godot's `PhysicsServer3D`, keeping ordinary Godot physics nodes and scenes usable.

The repository name distinguishes this fork. Projects still use the `addons/godot-box3d/` addon directory and the `Box3D Physics` backend; runtime identifiers and APIs are unchanged.

We maintain static embedding into custom Godot Web templates, application execution in a Web Worker, and the build tools and host patches needed for that configuration. General physics improvements continue to be offered upstream as focused pull requests. The upstream project's original motivation and development history belong to its author; see its [README](https://github.com/bearlikelion/godot-box3d#readme).

**Status: experimental.** Passing regressions establish a development baseline. Device support, startup latency, sustained frame pacing, and memory budgets require qualification for the application using the backend. See [physics readiness](docs/physics-readiness.md) and [release qualification](docs/release-qualification.md).

## Choose a Web build

| Profile | How Box3D is loaded | When to use it |
|---|---|---|
| Ordinary Web extension | A Wasm side module, using official Godot 4.7 dynamic-link templates | Start here for a normal addon export; follow the [Web quick start](WEB_QUICKSTART.md). |
| Static worker-main host | Box3D and godot-cpp archives linked into a custom Godot template | Use when the application's main loop must run in a worker; follow [static embedding](docs/static-embedding.md). |

For the ordinary Web profile, enable **Extensions Support**, disable **Thread Support**, select **Box3D Physics**, and use the Compatibility renderer. Fork builds and snapshots are listed in [this repository's Actions](https://github.com/waskosky/godot-box3d-embedded/actions) and [Releases](https://github.com/waskosky/godot-box3d-embedded/releases); check that the chosen artifact contains the required native editor and Web libraries. Upstream release addons remain available from [upstream Releases](https://github.com/bearlikelion/godot-box3d/releases), with their own feature set and dependency versions.

## Why maintain static embedding downstream?

Our goal is to keep the surrounding browser page responsive while the application loads and runs. The browser owns the DOM and page UI on its main thread. With `proxy_to_pthread=yes`, Godot's application main loop runs in a Web Worker. Physics worker threads are a separate setting; enabling them alone does not move the application's main loop.

At the [pinned Godot 4.7 revision](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/platform/web/detect.py#L294-L297), `dlink_enabled=yes` disables `proxy_to_pthread`. We therefore link the existing Box3D extension and its matching godot-cpp archive into a host template with dynamic linking disabled, then register it through Godot's function-based GDExtension loader. The [small host module](examples/godot_static/box3d_static) shows that registration without rewriting the physics adapter as an engine module.

This choice couples the backend to a custom template, exact dependency versions, thread deployment requirements, and host rendering behavior. Builds take longer and the host owns its release and rollback artifacts. Moving the main loop does not guarantee faster downloads, shorter startup, or responsive in-game menus during a blocking operation. Those benefits and costs must be measured in the actual application.

The upstream maintainer [prefers a small Web build](https://github.com/bearlikelion/godot-box3d/pull/26#pullrequestreview-5641515889) using the existing CMake project and official templates. That is a useful general-purpose support model. This fork carries the additional host configuration and its maintenance burden. The optional [WebGL readback patch](docs/web-worker-readback.md) applies to the documented proxied-context arrangement; it is not a change to Box3D's physics behavior.

## Branches and contributions

- `main` is the reviewed downstream baseline and the default starting point for this fork. Static-host qualification is recorded separately from ordinary extension CI.
- `integration/next` is the advancing feed for features and experiments. Development consumers can follow it; deployments should retain an immutable, qualified commit and its artifacts.
- `upstream/main` is the Git remote-tracking reference for bearlikelion's project. Upstream pull requests start from that reference and contain only their focused change.

Downstream `main` periodically promotes a tested integration snapshot. Keep baseline fixes and documentation in `integration/next` too. We track Godot, godot-cpp, Emscripten, and the original `erincatto/box3d` repository in [dependencies.lock](dependencies.lock). Consumer-specific application code and deployment configuration are maintained by their hosts.

## Physics support

The fork covers rigid/static/kinematic bodies, areas, direct queries, character motion, pin/hinge/slider joints, and primitive, convex, trimesh, heightmap, world-boundary, and query-only separation-ray shapes. Focused regressions cover shared resources, terrain and contact geometry, animated platforms, and rigid-body behavior.

Read [behavior differences](docs/behavior-differences.md) before adopting it. Unsupported joints, soft bodies, concave sensor visitors, scaling restrictions, and remaining qualification gates are explicit in the [readiness guide](docs/physics-readiness.md). General installation and native build instructions are in [installation](docs/installation.md) and [building](docs/building.md).

## License and credit

MIT; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The upstream Godot adapter is maintained by [bearlikelion](https://github.com/bearlikelion/godot-box3d), Box3D by [Erin Catto and contributors](https://github.com/erincatto/box3d), and Godot/godot-cpp by their respective contributors. The adapter takes structural inspiration from [godot-jolt](https://github.com/godot-jolt/godot-jolt).
