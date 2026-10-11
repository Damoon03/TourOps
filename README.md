# TourOps

An offline-first iOS app for touring teams. Teams, tours and shows are stored locally first and synchronized with a Supabase (PostgreSQL) backend when the network allows.

TourOps is a portfolio project. Its purpose is to work through the engineering problems of offline-first mobile apps: durable local writes, an operation queue, optimistic concurrency, retry and failure handling, and reconciling local state with a remote source of truth. The domain is deliberately small so the focus stays on those problems.

## Contents

- [Project status](#project-status)
- [Domain](#domain)
- [Architecture](#architecture)
- [Synchronization design](#synchronization-design)
- [Known limitations](#known-limitations)
- [Testing](#testing)
- [Getting started](#getting-started)
- [Backend contract](#backend-contract)
- [Project structure](#project-structure)
- [Tech stack](#tech-stack)
- [License](#license)

## Project status

### Implemented

- Email/password sign-in through Supabase Auth; the session state decides whether the login screen or the app is shown.
- Create, read, update and delete for teams, tours and shows, with SwiftUI navigation across the hierarchy.
- Local-first persistence with SwiftData. Every mutation is written locally before anything is sent.
- Local optimistic concurrency: an update based on an outdated version is rejected with `RepositoryError.staleVersion`.
- A durable queue of `SyncOperation` records. An entity change and its operation are committed in a single `ModelContext.save()`.
- A push sync engine with operation reduction, dependency ordering (team, then tour, then show), a retry policy, conflict detection, cancellation handling, recovery of operations left in `.processing`, and protection against lost wake-ups when sync is requested during a running sync.
- Server-side optimistic concurrency over PostgREST (version filter plus an empty-result check).
- A pull sync for all three entity types with status-aware reconciliation.
- Sync triggers: after every local mutation, when the user signs in, and when the app becomes active.

### Not implemented

- A screen for reviewing or resolving conflicted or failed operations.
- Background sync (`BGTaskScheduler`), network reachability monitoring, and timer-based retry with backoff.
- Pagination or incremental pull.
- UI tests. The UI test target contains only the Xcode template.
- Continuous integration.

See [Known limitations](#known-limitations) for the behaviors that matter before relying on the sync layer.

## Domain

```
Team → Tour → Show
```

A team has many tours, and a tour has many shows. Relationships are stored as plain UUID references (`Tour.teamID`, `Show.tourID`), not as SwiftData relationships. Lists are filtered by parent ID on the client.

The domain is intentionally minimal for now. Membership metadata (roles, permissions), equipment, setlists and related entities are out of scope until the sync layer is solid.

## Architecture

MVVM with a repository layer. Domain models are plain structs, and SwiftData entities never leave the data layer: they are converted through explicit mappers and DTOs.

```
SwiftUI View
     ↓
ViewModel            (@Observable, @MainActor)
     ↓
Repository protocol
     ↓
SyncTracking repository ──► SwiftData repository ──► SwiftData
        │
        └──► SyncOperation queue ──► SyncScheduler ──► SyncEngine ──► SyncService ──► Supabase REST
```

| Layer | Responsibility | Examples |
| --- | --- | --- |
| Domain/Model | Framework-agnostic value types | `Team`, `Tour`, `Show`, `SyncOperation` |
| Domain/Repositories | Repository contracts and errors | `ShowRepositoryProtocol`, `RepositoryError` |
| Domain/Sync | Sync policy and state machine | `SyncEngine`, `SyncOperationReducer`, `SyncRetryPolicy`, `SyncScheduler` |
| Domain/Network | Network contracts and error types | `APIClientProtocol`, `APIClientError` |
| Domain/Authentication | Auth state and the token provider seam | `AuthState`, `SyncAuthProviding` |
| Data/Persistence | SwiftData `@Model` entities | `TeamEntity`, `SyncOperationEntity` |
| Data/DTO, Data/Mappers | Wire types and Domain ⇄ DTO mapping | `ShowDTO`, `ShowMapper` |
| Data/Repositories | SwiftData repositories, sync-tracking decorators, reconcilers | `SwiftDataShowRepository`, `SyncTrackingShowRepository`, `ShowReconciler` |
| Data/Supabase, Data/Networking, Data/Sync | Supabase auth, REST push and pull, request building, pull coordinators | `SupabaseSyncService`, `SupabaseShowPullService`, `SyncRequestBuilder`, `ShowPullCoordinator` |
| Features/* | One View and ViewModel per screen | `ShowListView`, `ShowListViewModel` |

### Design notes

- **Dependency injection** is plain initializer injection. The composition root in `TourOpsApp.init` wires everything by hand.
- **No coordinator or use-case layer.** Navigation is handled with `NavigationStack` inside the views. This is a choice for the current size of the project.
- **Where the protocol boundary stops.** Repository protocols expose only fetch, create, update and delete. The `stage*` methods (mutate the context without saving) and the remote-apply methods exist only on the concrete `SwiftData*Repository` types, because the sync-tracking decorators and the reconcilers need to combine several changes under one save. The engine, scheduler, sync service, API client and auth provider sit behind protocols.
- **Concurrency.** The app target builds in Swift 5 language mode with default MainActor isolation and approachable concurrency enabled. Repositories, the engine, the scheduler and the reconcilers share the main `ModelContext`.
- **View refresh.** Views reload through `.task(id:)` keyed on a `DataRefreshSignal` generation counter, which the app bumps after a pull succeeds.

## Synchronization design

### Write path: one save, two records

```
ViewModel → SyncTracking repository
              1. stage the entity change          (no save)
              2. encode the DTO payload
              3. stage the SyncOperation          (no save)
              4. modelContext.save()              (single commit)
              5. syncScheduler.scheduleSync()
```

Staging both records and saving once means a committed local change always has a matching operation. No suspension point sits between staging and the save, and everything runs on the main actor against one context.

An operation records two version numbers. `operation.version` is the version the server is expected to hold (the base), and the payload carries the post-update version (`base + 1`).

### Push: SyncEngine

1. Fetch pending operations. Operations stuck in `.processing` from an interrupted run are reset to `.pending` first.
2. Group by entity, and order groups team, then tour, then show, then by creation time.
3. Reduce each group (see below). Superseded operations are deleted before the remaining one is sent.
4. Mark the operation `.processing`, execute it through `SyncServiceProtocol`, and delete it on success.
5. If a sync is requested while one is running, the engine records the request and runs again when the current pass ends.

`SyncScheduler` coalesces triggers. `scheduleSync()` is fire-and-forget, and `syncNow()` awaits the running or a new sync.

### Operation reduction

| Sequence for one entity | Result |
| --- | --- |
| create, then update(s) | one create with the latest payload and the original version |
| create, then delete | both dropped; nothing is sent |
| update, then update | one update with the original base version and the latest payload |
| update, then delete | the delete |

Any other sequence falls through to "the later operation replaces the earlier one" and is not specifically tested.

### Failure handling

| Outcome | Result |
| --- | --- |
| `SyncError.conflict` (HTTP 409 on update or delete, or an empty representation) | `.conflict`, no retry |
| `APIClientError.networkError` | back to `.pending`, retry count unchanged |
| Non-retryable `APIClientError` (decoding failure, 4xx) | `.failed` |
| Any other error, including 5xx | retry count + 1; `.pending` while the count is below the limit (3), otherwise `.failed` |
| Cancellation | back to `.pending` |

Only `.pending` operations are fetched for sending, so `.conflict` and `.failed` operations are not retried automatically. There is no backoff: a failed attempt is retried at the next trigger.

### Concurrency control against the server

Updates and deletes are sent as PostgREST requests filtered on the expected version:

```
PATCH  /rest/v1/shows?id=eq.<id>&version=eq.<base>
DELETE /rest/v1/shows?id=eq.<id>&version=eq.<base>
```

The request asks for `Prefer: return=representation`. If the filter matches no row, the response is an empty array and the client treats it as a conflict. Creates carry no filter.

An empty result can mean a version mismatch, a row deleted elsewhere, or a row the user is not allowed to see. The client does not distinguish between them.

### Idempotency of creates

Entity IDs are generated on the client and used as primary keys. If a create is replayed, the duplicate is rejected by the server, and an HTTP 409 on a create is treated as success. Updates and deletes are not designed to be replayed safely.

### Pull and reconciliation

After pushing, the app fetches all teams, tours and shows and reconciles each set against local data:

| Situation | Rule |
| --- | --- |
| Remote entity missing locally | Create it locally, unless a pending or processing delete exists for it |
| Local entity has a pending, processing or conflicted operation | Keep the local version |
| Local entity has no blocking operation (failed operations do not block) | Apply the remote version only if `remote.version > local.version` |
| Local entity missing from the remote result | Delete it locally only if it has no operations of any status |
| Remote result is empty while local data exists | Never treated as "delete everything" |

Each entity type is pulled independently; a failure in one is logged and does not stop the others.

### Triggers

- `scheduleSync()` after every local mutation.
- Push, then pull, when the user signs in and whenever the app becomes active.

## Known limitations

- **Conflicts and failures are parked, not resolved.** There is no UI for them, and they are not retried automatically.
- **A failed local edit can be overwritten.** Because failed operations do not protect an entity during reconciliation, a newer remote version replaces a local edit whose operation has failed, with no audit trail.
- **Replay safety.** Only creates are idempotent. A create that the server rejects with 409 for any reason, including other constraint violations, is treated as already applied.
- **Pull is a full snapshot.** Each pull fetches whole tables without pagination and infers remote deletions from absence. Only an empty response is guarded against.
- **No local cascade.** Deleting a team removes only the team; its tours and shows remain in the local store. Repository fetches are unscoped and filtered in the views.
- **Errors are mostly silent in the sync path.** Persistence errors inside the engine are swallowed, and only the pull path logs.
- **Offline launch with an expired session is untested.** The sign-in gate treats an expired session as signed out; its behavior without a network has not been verified.
- **Backend artifacts are not included.** The SQL schema, row level security policies and any triggers are not part of this repository.
- **Overlapping sync runs.** The sign-in and app-active triggers may start a push and pull at nearly the same time at launch; overlapping pulls are not guarded against. `SyncScheduler` coalesces concurrent `scheduleSync()` calls for push, but the pull path is not yet serialized with the same guarantee.

## Testing

Unit tests use Swift Testing, with more than 170 test functions. They cover:

- **SyncEngine:** success, retry, retry limit, conflict, cancellation, lost wake-up, reduction integration, entity ordering.
- **SyncOperationReducer** and **SyncRetryPolicy**.
- **SyncScheduler:** coalescing, `syncNow()`, cancellation.
- **SupabaseSyncService** and **SyncEndpoint:** version-filtered URLs, empty-result and 409 handling, create idempotency.
- The Show and Team pull services, the Tour and Show pull coordinators, and the Team, Tour and Show reconcilers, including the full operation-status matrix.
- SwiftData repositories and the sync-tracking repositories, against an in-memory `ModelContainer`.
- **APIClient** through a `URLProtocol` stub, JSON date decoding, and the list ViewModels.

Network, auth and the sync service are mocked in the engine and service tests. Repository, tracking and reconciler tests use a real in-memory SwiftData store instead of mocking SwiftData.

There is no CI configuration. Run the suite with **Cmd+U** in Xcode.

## Getting started

**Requirements:** Xcode with the iOS 26 SDK (deployment target is iOS 26.0) and a Supabase project.

1. Open `TourOps.xcodeproj`. Swift Package Manager resolves `supabase-swift`.
2. Point the app at your Supabase project by setting `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in the TourOps target's build settings. They are injected into `Info.plist` and read at launch; the app stops with an error if either is missing.
3. Create the tables described in the [backend contract](#backend-contract) and enable row level security.
4. Create a user in Supabase Auth, build and run the **TourOps** scheme on an iOS 26 simulator or device, and sign in.

## Backend contract

The schema is not included in this repository. The client expects three tables — `teams`, `tours` and `shows` — reachable through Supabase's REST interface, with these columns:

| Table | Columns |
| --- | --- |
| `teams` | `id` (uuid), `name`, `genre`, `country`, `city`, `created_at`, `version` (integer), `user_id` |
| `tours` | `id` (uuid), `team_id`, `name`, `start_date`, `end_date`, `created_at`, `version` (integer), `user_id` |
| `shows` | `id` (uuid), `tour_id`, `name`, `venue`, `city`, `date`, `created_at`, `version` (integer), `user_id` |

- The client sets `user_id` from the signed-in session on create operations only.
- Dates are ISO 8601; decoding accepts timestamps with or without fractional seconds.
- On update, the client sends the post-update version in the payload and filters on the previous version. Whether the server also owns or increments `version` (for example with a trigger) is a backend concern outside this repository.
- Access control depends entirely on the row level security policies you configure.

## Project structure

```
TourOps/
├── App/            Composition root (TourOpsApp), DataRefreshSignal
├── Domain/
│   ├── Authentication/   AuthState, SyncAuthProviding
│   ├── Model/            Team, Tour, Show, ShowStatus, SyncOperation
│   ├── Network/          APIClient and its protocol and errors
│   ├── Repositories/     Repository protocols, RepositoryError
│   └── Sync/             SyncEngine, reducer, retry policy, scheduler, service protocols
├── Data/
│   ├── Authentication/   AuthSessionController
│   ├── DTO/              Codable wire types
│   ├── Mappers/          Domain ⇄ DTO
│   ├── Networking/       Endpoint, SyncEndpoint, SyncRequestBuilder, JSONCoding
│   ├── Persistence/      SwiftData entities
│   ├── Repositories/     SwiftData, sync-tracking and mock repositories, reconcilers
│   ├── Supabase/         Client, auth, push and pull services
│   └── Sync/             DefaultSyncService, pull coordinators
└── Features/       Authentication, Teams, Tours, Show

TourOpsTests/       Swift Testing unit tests (Network, Repositories, Sync, ViewModels)
TourOpsUITests/     Xcode template only
```

`DefaultSyncService` is a generic REST sync service kept alongside `SupabaseSyncService`; the app uses the Supabase one. `ShowStatus` is defined in the domain layer but not yet used.

## Tech stack

| Category | Technology |
| --- | --- |
| Language | Swift 5 language mode, default MainActor isolation |
| UI | SwiftUI, NavigationStack |
| State | Observation (`@Observable`) |
| Concurrency | async/await, structured and unstructured Task |
| Local persistence | SwiftData |
| Networking | URLSession through a small APIClient |
| Backend | Supabase: PostgreSQL, Auth, PostgREST |
| Dependencies | supabase-swift (authentication) |
| Testing | Swift Testing; XCTest for the UI test template |

## License

MIT. See [LICENSE](LICENSE).
