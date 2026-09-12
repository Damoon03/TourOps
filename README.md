# TourOps

An offline-first iOS app for managing music tours: teams, tours, and shows, with local-first persistence and a sync layer designed to reconcile local and remote state.

TourOps is a portfolio project focused on the engineering problems behind offline-first mobile apps — not on how many features a CRUD screen can have. The current codebase implements the local persistence and CRUD layer end-to-end, and a sync-operation queue with a reducer, retry policy, and conflict-detection primitives. It does **not** yet talk to a real backend.

---

## Overview

The domain is a simple hierarchy:

```
Team → Tour → Show
```

A team can run multiple concurrent tours, and each tour contains multiple shows. The app is built to work fully offline: every mutation is written to local storage first, and is meant to be reconciled with a remote backend independently of whether the device is online at the time.

## Why TourOps exists

This project exists to work through a specific set of problems that don't show up in a typical tutorial CRUD app:

- How does the app behave when the network is unavailable?
- How do you coordinate a local mutation with the metadata needed to sync it, without risking one succeeding and the other failing?
- How do you avoid sending the same mutation to the server twice?
- How do you detect that a change conflicts with what's already on the server — and what do you do once you've detected it?
- How does persistence state stay consistent with sync state as the app evolves?
- How do you keep an architecture testable as more of this gets built?

TourOps is deliberately scoped to a small, concrete domain (touring/band management) so the focus stays on these questions rather than on breadth of features.

## Key features

**Implemented:**
- Full CRUD for Teams, Tours, and Shows, with SwiftUI navigation across the hierarchy
- Local-first persistence via SwiftData
- Optimistic-concurrency version checks on local updates (a stale local write is rejected before it overwrites newer local state)
- A `SyncOperation` queue: every create/update/delete is staged as a durable, persisted operation alongside the entity mutation
- Operation reduction: redundant operations for the same entity (e.g. two rapid edits) are collapsed before being sent
- A retry policy with a configurable retry limit
- Conflict detection in the sync layer, driven by an HTTP 409 response
- A `URLSession`-based API client and request builder, decoupled from the sync engine behind protocols

**Planned / not yet implemented:**
- Any actual connection to a backend (see [Backend / Supabase](#backend--supabase))
- Authentication
- A UI surface for reviewing or resolving sync conflicts
- Background sync (the scheduler currently only supports foreground-triggered sync, and is not yet wired into app lifecycle events — see [Development Status](#development-status))
- Conflict resolution UI (Keep Local / Keep Server / Keep Draft) and an audit trail of discarded changes

## Architecture

MVVM, with a Repository layer sitting between ViewModels and persistence/network, and a Domain/Data split enforced through explicit mapping — SwiftData entities never leak into the Domain or Feature layers.

```
SwiftUI View
     ↓
ViewModel  (@Observable, @MainActor)
     ↓
Repository (protocol)
     ↓
SwiftData (local)  ·  Sync layer (staged async, see below)
```

There is no Coordinator layer and no Application Service / Use Case layer. Navigation is handled directly by SwiftUI's `NavigationStack`/`NavigationLink` from within Views. This is a deliberate choice for the current project size, not an oversight — a coordinator or use-case layer would add indirection without solving a problem this codebase currently has.

Dependency injection is via plain initializer injection — no DI container or framework.

### Layer responsibilities

| Layer | Responsibility | Example |
|---|---|---|
| `Domain/Model` | Plain, framework-agnostic structs | `Team`, `Tour`, `Show` |
| `Domain/Repositories` | Repository contracts | `TeamRepositoryProtocol` |
| `Domain/Sync` | Sync policy and state machine, no persistence or network dependency | `SyncEngine`, `SyncOperationReducer`, `SyncRetryPolicy` |
| `Domain/Network` | Network contracts and error types | `APIClientProtocol`, `APIClientError` |
| `Data/Persistence` | SwiftData `@Model` entities | `TeamEntity`, `SyncOperationEntity` |
| `Data/Mappers` | Explicit Domain ⇄ DTO mapping | `TeamMapper` |
| `Data/Repositories` | Concrete repository implementations | `SwiftDataTeamRepository`, `SyncTrackingTeamRepository` |
| `Data/Sync` / `Data/Networkng` | Concrete sync service, request building | `DefaultSyncService`, `SyncRequestBuilder` |
| `Features/*` | Per-screen View + ViewModel pairs | `TeamListView` / `TeamListViewModel` |

## Project structure

```
TourOps/
├── App/
│   └── TourOpsApp.swift            # Composition root: builds the ModelContainer,
│                                    # repositories, and sync engine by hand
├── Domain/
│   ├── Model/                      # Team, Tour, Show, SyncOperation (plain structs)
│   ├── Repositories/               # Repository protocols + RepositoryError
│   ├── Sync/                       # SyncEngine, SyncOperationReducer, SyncRetryPolicy
│   └── Network/                    # APIClientProtocol, APIClientError
├── Data/
│   ├── Persistence/                # SwiftData @Model entities
│   ├── DTO/                        # Codable wire types
│   ├── Mappers/                    # Domain ⇄ DTO
│   ├── Repositories/                # SwiftData-backed + sync-tracking repositories
│   ├── Sync/                       # DefaultSyncService
│   └── Networkng/                  # Endpoint definitions, SyncRequestBuilder
└── Features/
    ├── Teams/
    ├── Tours/
    └── Show/

TourOpsTests/                       # Swift Testing unit tests
TourOpsUITests/                     # Default Xcode UI test target (not yet implemented)
```

## Offline-first approach

Every mutation goes to local SwiftData storage first. There is no "write to server, then cache" path — the app is designed to be fully usable with no network connection, with sync happening independently and asynchronously.

Reads and writes go through repository protocols, so ViewModels never touch SwiftData or the network directly.

## Synchronization architecture

The core mechanism is a `SyncOperation`: a durable record of a pending mutation, persisted in SwiftData alongside the entity it describes.

```swift
struct SyncOperation {
    let id: UUID
    let entityID: UUID
    let entityType: SyncEntityType       // .team / .tour / .show
    let operationType: SyncOperationType // .create / .update / .delete
    let payload: String?                 // encoded DTO, for create/update
    let version: Int
    let createdAt: Date
    var status: SyncOperationStatus      // .pending / .processing / .failed / .conflict
    var retryCount: Int
}
```

`SyncOperation.id` is intended to eventually serve as an idempotency key when a create/update is retried against the backend. **This is not yet used that way anywhere in the request pipeline** — it's a stated design goal, not current behavior.

### Write flow (implemented)

```
User mutation (e.g. update a Show)
        ↓
Repository stages the local entity mutation
        ↓
Repository encodes a matching SyncOperation
        ↓
Both are inserted into the same ModelContext
        ↓
A single modelContext.save() commits both together
```

This single-transaction guarantee is deliberate: an entity mutation and its corresponding `SyncOperation` are always persisted together, so there is no window where a local change exists without a corresponding sync record (or vice versa). `SyncTrackingShowRepository` (and its Team/Tour equivalents) are the components responsible for this coordination — they wrap the plain SwiftData repository and stage the sync operation before calling `save()` once.

### Sync engine (implemented, not yet wired to run automatically)

```
SyncEngine.sync()
        ↓
Fetch all pending operations
        ↓
Reduce: collapse redundant operations per entity
   (e.g. two updates → keep the latest; create+delete → drop both)
        ↓
For each remaining operation:
   mark .processing → execute via SyncService → on success, delete the operation
```

Failure handling, per the current implementation:

```
Execution fails
        ↓
   HTTP 409 from server  →  status = .conflict   (no retry)
   any other error       →  retryCount += 1
                              ├─ under retry limit → status = .pending (retried on next sync)
                              └─ limit reached      → status = .failed
```

`SyncOperationReducer` and `SyncRetryPolicy` are standalone, independently unit-tested types with no persistence or network dependency — they operate purely on `[SyncOperation]` / `SyncOperation` values.

**What this is, honestly:** a sync *engine* that correctly reduces, executes, and re-queues operations against a mocked `SyncServiceProtocol`, verified by unit tests. **What it is not yet:** something that runs automatically. `SyncScheduler` exists and can trigger a sync on demand, but it is not currently hooked into app lifecycle (launch, foreground, or network-reachability changes) — that wiring is still to be done. There is also currently no UI that shows the user a `.conflict` or `.failed` operation once one exists.

## Data layer

Local persistence uses SwiftData. Each domain entity has a matching `@Model` class (`TeamEntity`, `TourEntity`, `ShowEntity`, `SyncOperationEntity`), converted to/from the plain `Domain/Model` structs via `toDomain()` / `init(entity:)`-style mapping — the Domain layer has no SwiftData import anywhere.

Optimistic concurrency is enforced at the repository level: every entity carries a `version: Int`, and a local update is rejected (`RepositoryError.staleVersion`) if the version it's based on doesn't match what's currently persisted.

Repository protocols currently expose only unscoped fetches (`fetchTours() -> [Tour]`, not `fetchTours(teamID:)`); screens filter the result client-side. This is a known limitation, not a design choice — see [Future Work](#future-work).

## Backend / Supabase

The intended backend is **Supabase (PostgreSQL + Auth), with hand-written Row Level Security policies**.

**Current state: no backend integration exists in this repository.** Specifically:
- No Supabase SDK or any external Swift package is added to the project (`packageProductDependencies` is empty in the Xcode project).
- `APIClient` is a small, generic `URLSession`-based client with no knowledge of Supabase — it just sends a `URLRequest` and decodes a `Decodable` response.
- The API base URL used at composition-root time is a placeholder (`https://example.com`).
- There is no authentication of any kind — no token attachment, no login flow, no `Authorization` header.

The networking layer is intentionally backend-agnostic at this stage: `APIClientProtocol` and `SyncRequestBuilderProtocol` are the seams a real Supabase-backed implementation will plug into, but that implementation doesn't exist yet.

## Testing

Unit tests are written with **Swift Testing** and cover:

- `SyncOperationReducer` — operation-collapsing rules (update+update, create+update, create+delete, update+delete)
- `SyncRetryPolicy` — retry-limit logic
- `SyncEngine` — full state-transition coverage against mocked repository/service collaborators (success, retry, retry-limit-reached, conflict, reduction integration)
- `DefaultSyncService` — HTTP 409 → `SyncError.conflict` mapping
- `APIClient` — success decoding and non-2xx error mapping, via a `URLProtocol`-based mock session
- Repository layer — `SwiftDataTeamRepository`, `SwiftDataTourRepository`, `SwiftDataShowRepository`, `SwiftDataSyncOperationRepository`, and the `SyncTracking*Repository` wrappers, all tested against an in-memory `ModelContainer` (no mocking of SwiftData itself)
- ViewModels — `TeamListViewModel`, `TourListViewModel`, `ShowListViewModel`

The `TourOpsUITests` target exists but currently only contains Xcode's default generated template (an empty launch test and a launch-performance measurement) — no UI tests have been written yet.

No CI pipeline is currently configured for this repository, so there are no build/test status badges here.

## Tech stack

| Category | Technology |
|---|---|
| Language | Swift |
| UI | SwiftUI |
| Concurrency | Swift Concurrency (`async`/`await`) |
| State | `@Observable` (Observation framework) |
| Local persistence | SwiftData |
| Networking | `URLSession` (no third-party networking library) |
| Serialization | `Codable` |
| Testing | Swift Testing (unit), XCTest (UI test scaffold) |
| Planned backend | Supabase (PostgreSQL, Auth, Row Level Security) |

## Requirements

- Xcode with SwiftData / Swift Testing support (Xcode 16 or later)
- iOS 26 deployment target (as currently configured in the project)

## Getting started

```bash
git clone https://github.com/Damoon03/TourOps.git
cd TourOps
open TourOps.xcodeproj
```

Build and run the `TourOps` scheme on an iOS 26+ simulator or device. The app runs fully offline out of the box — there is no backend configuration required to use it, because there is no backend integration yet.

To run the test suite: `Cmd+U` in Xcode, or

```bash
xcodebuild test -project TourOps.xcodeproj -scheme TourOps -destination 'platform=iOS Simulator,name=iPhone 16'
```

There are no environment variables or `.env` files required or used by this project at this time.

## Development status

This project is under active, incremental development as part of a structured iOS engineering learning plan. Current state, honestly:

- ✅ Domain models, SwiftData persistence, and full CRUD are implemented and tested for all three entities
- ✅ The sync-operation queue, reducer, retry policy, and conflict-detection logic are implemented and unit-tested in isolation
- 🚧 The sync engine is not yet triggered automatically by app lifecycle events
- 🚧 There is no UI for viewing or resolving sync conflicts
- 📋 Backend integration (Supabase, Auth, RLS) has not started
- 📋 Background sync has not started

## Future work

- Wire `SyncScheduler` into app lifecycle (launch, foreground, reachability changes)
- Implement the Supabase backend: schema, RLS policies, and a sync endpoint
- Add authentication and attach tokens to outgoing requests
- Build conflict-resolution UI (Keep Local / Keep Server / Keep Draft) backed by a `DiscardedChange` audit entity
- Add scoped repository fetches (e.g. `fetchTours(teamID:)`) instead of client-side filtering
- Background sync via `BGTaskScheduler`
- Recovery handling for operations left in `.processing` after an app termination mid-sync

## License

MIT — see [LICENSE](LICENSE).
