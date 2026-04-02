# CutePaws (SwiftUI + SwiftData + MVVM)

CutePaws is a production-style dog media app: curated daily picks, spotlight and mini moments, breed explore with thumbnails, and favorites — built with SwiftUI, SwiftData, and a small clean-architecture slice (repositories, remote data, local stores).

It is a **portfolio project** to show how I structure a real-world SwiftUI app: clear layers, protocol-driven data access, bounded concurrency for downloads, and polished presentation (masonry grid, full-screen detail, navigation flows) without unnecessary framework weight.

**Data source credit**

- [Dog.Ceo Dog API](https://dog.ceo/dog-api/)
- [Random.Dog](https://random.dog/)

---

## Portfolio summary

This project highlights:

- **SwiftUI + Observation** (`@Observable`, `@Bindable`) for modern screen state
- A **feature-first layout** under `Features/Discover` with **Domain / Data / Presentation** separation
- **Repository protocols** in Domain, implementations in Data, composed in **`AppDependencies`**
- **Multiple remote APIs** (Dog CEO vs Random.Dog) behind small, focused **remote data sources**
- **SwiftData** with **multiple store files** and typed `@Model` persistence for each concern
- **Disk + database coordination** via `MediaFileStorage` buckets and SwiftData rows
- **Media quality gates**, image compression for thumbnails, and **async download** patterns with explicit limits
- **Structured logging** via `AppLogger` for debug-friendly tracing

---

## Features

- **Daily Picks** — masonry grid of dog photos, cached and refreshed with sensible limits
- **Spotlight** — hero image from Random.Dog with rotation / cycle logic
- **Mini Moments** — short video rail (Random.Dog), with optional bundled preview when empty
- **Explore breeds** — Dog CEO breed list, background thumbnail bootstrap, per-breed gallery
- **Favorites** — persist favorites and open them in the shared full-screen detail experience
- **About sheet** — credits, open-source link, privacy bullets (no ads / no data collection)

---

## Skills demonstrated

- Designing a **Discover-centric** SwiftUI shell with custom chrome, `NavigationStack` for Explore, and **full-screen covers** for detail and favorites
- Applying **MVVM** with thin views, async view-model flows, and extensions to keep large VMs readable
- Implementing **Clean Architecture–style boundaries** without over-abstracting (protocols where they buy composition or test seams)
- **Async/await** networking, `Task` / task groups, and **bounded concurrency** (e.g. semaphores for parallel work)
- **SwiftData** model design, invalidation / trimming, and **multiple `ModelContainer`** instances
- Normalizing **shared DTOs** (e.g. list-style API responses) across remote callers
- **HTTP session tuning** (separate clients for snappy Dog CEO traffic vs slower Random.Dog responses) where it matters
- **Image pipeline**: download, optional compression, metadata / aspect ratio, on-disk paths referenced from SwiftData

---

## Architecture overview

Lightweight layering: protocols protect boundaries; concrete types stay where extra abstraction would only add noise.

For a deeper file-by-file map, see [DOCUMENTATION.md](DOCUMENTATION.md).

### Layer responsibilities

#### App

- Bootstrap, **`AppDependencies`** composition, SwiftData container creation, factory for `DiscoverViewModel`
- Media quality presets (`AppDependencies+MediaQuality`)

Key areas: `App/AppDependencies.swift`, `AppDependencies+Factories.swift`, `AppDependencies+SwiftDataContainers.swift`, `CutePawsApp.swift`

#### Presentation

- SwiftUI views, view models, components (spotlight, masonry, rails, detail, favorites, explore)

Key areas: `Features/Discover/Presentation/`

#### Domain

- Entities (`MediaItem`, favorites, explore snapshots, …), **repository protocols**, small domain helpers

Key areas: `Features/Discover/Domain/`

#### Data

- Repository implementations, **remote data sources** (Dog CEO, Random.Dog), SwiftData stores, DTOs, download / quality / compression services

Key areas: `Features/Discover/Data/`

#### Core

- Shared networking (`HTTPUtility`, `APIConstants`), concurrency helpers, logging

Key areas: `Core/`

---

## Flows (conceptual)

### Daily picks

```text
DiscoverView
  → DiscoverViewModel
  → DiscoverRepository
  → DiscoverRepositoryImpl
  → DogCeoRemoteDataSource + ImageDownloadService + SwiftDataDiscoverStore
```

### Spotlight / mini moments

```text
DiscoverViewModel
  → SpotlightRepository / MiniMomentRepository
  → RandomDog*RemoteDataSource + stores + file storage
```

### Explore breeds

```text
ExploreBreedView / BreedImagesView
  → BreedGalleryRepository
  → DogCeoBreedGalleryRemoteDataSource + SwiftData breed stores + thumbnail / gallery pipeline
```

### Favorites

```text
FavoritesView
  → FavoriteRepository
  → SwiftDataFavoriteStore + favorites file storage
```

---

## Dual API setup

The UI does not hard-code provider URLs or response shapes:

- **Dog CEO** powers daily picks, breed lists, and breed gallery URL lists.
- **Random.Dog** powers spotlight and mini-moment assets, with quality filtering at the repository layer.

Remote types stay small; repositories orchestrate fetch, quality checks, persistence, and trimming.

---

## Tech stack

- Swift / SwiftUI
- **Observation** (`@Observable`)
- Swift concurrency (`async` / `await`, structured concurrency)
- **SwiftData** (multiple containers / store files)
- `URLSession` via **`HTTPUtility`**
- Structured logging (`AppLogger`)

---

## Key behaviors

- Separate SwiftData stores per feature area (discover, spotlight, mini moments, breed gallery, favorites)
- On-disk media organized by **named storage buckets** under Application Support
- Daily refresh / fill-to-target patterns for grids and rails without blocking the main thread
- Breed thumbnail bootstrap with **bounded parallelism**
- Explore gallery prefetch with **time budgets** and per-download timeouts
- Full-screen **image / video detail** shared across flows

---

## Project structure (high level)

```text
CutePaws/
├── App/
│   ├── CutePawsApp.swift
│   ├── AppDependencies.swift
│   ├── AppDependencies+Factories.swift
│   ├── AppDependencies+MediaQuality.swift
│   ├── AppDependencies+SwiftDataContainers.swift
│   ├── AppDefaults.swift
│   └── …
├── Core/
│   ├── Concurrency/
│   ├── Networking/
│   └── …
└── Features/
    └── Discover/
        ├── Data/
        │   ├── DTO/
        │   ├── Remote/
        │   ├── Repositories/
        │   ├── Services/
        │   └── Store/
        ├── Domain/
        └── Presentation/
            ├── Discover/
            ├── Detail/
            ├── Explore/
            ├── Favorites/
            └── Components/
```

---

## Getting started

### Prerequisites

- Xcode (recent release recommended)
- No API keys required for the public Dog CEO and Random.Dog endpoints used in this project

### Run

1. Open `CutePaws.xcodeproj` in Xcode.
2. Select an iOS Simulator or device.
3. Build and run the **CutePaws** scheme.

---

## Screenshots & demo

Add a `Screenshots/` folder and link key frames here when you publish the repo (Discover grid, Explore, detail, favorites).

Optional: add a short screen recording link (e.g. YouTube) in this section.

---

## Author

**Vijay Raj Dixit** — iOS freelance developer (SwiftUI / UIKit).  
Portfolio / code: [github.com/pvrdixit](https://github.com/pvrdixit)

---

## License

MIT License. See [LICENSE](LICENSE).
