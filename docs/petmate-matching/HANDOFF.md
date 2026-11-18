# PetMate Matching & Discovery Handoff

## PART 1 DONE: Discover Feed & Swipes

### 1. Files Changed
- `backend/prisma/schema.prisma`: Added `SwipeAction` enum (`LIKE`, `PASS`), `username` on `Profile`, `PetSwipe` model, and relations on `User` and `Pet`.
- `backend/prisma/migrations/20261118140000_add_pet_swipe/migration.sql`: Non-destructive migration creating `pet_swipes` table and adding unique `username` to `profiles`.
- `backend/src/modules/matching/matching.service.ts`: Implemented `getDiscoverFeed` with cursor pagination, exclusions, sanitized projection (no private fields), and `recordSwipe` with transaction and idempotency.
- `backend/src/modules/matching/matching.controller.ts`: Controllers `getDiscover` and `postSwipe` verifying inputs and req.user context.
- `backend/src/modules/matching/matching.routes.ts`: Mounted on `/discover` and `/swipes`, guarded by `authenticateFirebase`, `requireInitializedUser`, and `requireRole(Role.PET_OWNER, Role.ADMIN)`.
- `backend/src/app.ts`: Mounted matching routes under `/api` and `/api/v1`.
- `backend/test/matching.test.ts`: Backend unit tests for `calculateAgeString`, swipe actions, self-swipe rejection, and response field sanitization.
- `lib/features/home/domain/entities/discovery_pet.dart`: Added optional `ownerUsername` and `ownerId` fields.
- `lib/features/home/data/models/discovery_pet_model.dart`: Added JSON parsing for `ownerUsername`, `ownerId`, and Cloudinary image fallbacks.
- `lib/features/home/data/repositories/matching_repository.dart`: Created repository with `getDiscover` and `recordSwipe` via `ApiClient`.
- `lib/features/home/presentation/providers/discovery_provider.dart`: Rewrote notifier to manage active pet, page 1 loading, queue prefetching when $\le 3$ cards remain, optimistic background swipe with single retry, debounce lock, and snackbar reporting.
- `lib/features/home/presentation/pages/home_page.dart`: Added active pet chips selector (for users with multiple pets), 0-pet "Add Pet" prompt, loading skeleton, error retry state, and background swipe error snackbar listener.
- `test/discover_test.dart`: Flutter unit tests for queue loading, optimistic swipe pop, prefetch trigger, empty queue state, and non-fatal retry.

### 2. Prisma Models & Fields Implemented
```prisma
enum SwipeAction {
  LIKE
  PASS
}

model PetSwipe {
  id           String      @id @default(uuid())
  swiperUserId String      @map("swiper_user_id")
  swiperPetId  String      @map("swiper_pet_id")
  targetPetId  String      @map("target_pet_id")
  targetUserId String      @map("target_user_id")
  action       SwipeAction
  createdAt    DateTime    @default(now()) @map("created_at")

  swiperUser User @relation("SwipesGiven", fields: [swiperUserId], references: [id], onDelete: Cascade)
  targetUser User @relation("SwipesReceived", fields: [targetUserId], references: [id], onDelete: Cascade)
  swiperPet  Pet  @relation("PetSwipesGiven", fields: [swiperPetId], references: [id], onDelete: Cascade)
  targetPet  Pet  @relation("PetSwipesReceived", fields: [targetPetId], references: [id], onDelete: Cascade)

  @@unique([swiperPetId, targetPetId])
  @@index([swiperPetId])
  @@index([targetPetId])
  @@map("pet_swipes")
}
```

### 3. Endpoint Contracts Implemented

#### `GET /api/discover` (and `/api/v1/discover`)
- **Query Parameters**:
  - `petId` (required string): ID of the active swiping pet owned by caller.
  - `cursor` (optional string): Pagination cursor (ID of last pet from previous page).
  - `limit` (optional integer, default 10, max 50).
- **Security**: Requires verified Firebase ID token and active user. Caller must own `petId`.
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Discover feed retrieved successfully",
  "data": {
    "pets": [
      {
        "id": "pet-uuid",
        "name": "Milo",
        "petName": "Milo",
        "petAge": "2 years old",
        "dateOfBirth": "2024-01-01T00:00:00.000Z",
        "animalType": "Dog",
        "breed": "Golden Retriever",
        "petBreed": "Golden Retriever",
        "gender": "Male",
        "petGender": "Male",
        "color": "Golden",
        "personality": ["Friendly", "Playful"],
        "vaccinationStatus": "Fully vaccinated",
        "allergies": null,
        "bio": "Loves parks and fetch.",
        "petBio": "Loves parks and fetch.",
        "imageUrl": "https://res.cloudinary.com/.../pet.jpg",
        "petImageUrl": "https://res.cloudinary.com/.../pet.jpg",
        "ownerId": "owner-user-uuid",
        "ownerName": "Aarav Sharma",
        "ownerUsername": "Aarav Sharma",
        "ownerLocation": "Jhamsikhel, Lalitpur",
        "ownerAvatarUrl": "https://res.cloudinary.com/.../avatar.jpg",
        "createdAt": "2026-11-18T10:00:00.000Z"
      }
    ],
    "nextCursor": "pet-next-uuid",
    "hasMore": true
  }
}
```
- **Guarantees**: Private fields (`email`, `phoneNumber`, `firebaseUid`) are strictly omitted.

#### `POST /api/swipes` (and `/api/v1/swipes`)
- **Body**:
```json
{
  "petId": "caller-pet-uuid",
  "targetPetId": "target-pet-uuid",
  "action": "LIKE" // or "PASS"
}
```
- **Security & Validation**: Caller must own `petId`. `targetPetId` must exist and not belong to caller. Cannot swipe on own pet.
- **Idempotency**: Wrapped in `prisma.$transaction`. Duplicate calls return existing status without errors (catches P2002).
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Swipe recorded successfully",
  "data": {
    "status": "recorded"
  }
}
```

### 4. Flutter Classes & Providers
- `DiscoveryPet` ([discovery_pet.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/domain/entities/discovery_pet.dart)): Entity with `ownerUsername` and `ownerId`.
- `DiscoveryPetModel` ([discovery_pet_model.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/data/models/discovery_pet_model.dart)): JSON deserializer matching backend response.
- `MatchingRepository` / `matchingRepositoryProvider` ([matching_repository.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/data/repositories/matching_repository.dart)): Network abstraction using `ApiClient`.
- `DiscoveryState` & `DiscoveryNotifier` / `discoveryProvider` ([discovery_provider.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/presentation/providers/discovery_provider.dart)): Riverpod notifier handling active pet selection, initial feed loading, prefetching, optimistic card pop, and background swipe retry.
- `HomePage` ([home_page.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/presentation/pages/home_page.dart)): Deck UI wiring, active pet chip switcher, 0-pet "Add Pet" prompt, loading skeleton, error retry button, and swipe error snackbar listener.

### 5. Hooks Left for Future Parts
- In `backend/src/modules/matching/matching.service.ts`:
  - `// PART 2 HOOK: also exclude users with a pending request`: In candidate feed query `where` clause.
  - `// PART 3 HOOK: also exclude users with a match`: In candidate feed query `where` clause.
  - `// PART 2 HOOK: where the connection request creation will go`: In `recordSwipe` after recording a `LIKE` swipe inside the transaction.

### 6. Known Issues / Notes
- None. All 14 backend unit tests pass, and all 19 Flutter tests pass with clean analysis.

---

## PART 2 DONE: Connection Requests & Incoming Requests UI

### 1. Files Changed
- **Backend**:
  - `backend/prisma/schema.prisma`: Added `RequestStatus` enum (`PENDING`, `ACCEPTED`, `REJECTED`), `ConnectionRequest` model, and relations on `User` (`requestsSent`, `requestsReceived`) and `Pet` (`requestsSent`, `requestsReceived`).
  - `backend/prisma/migrations/20261118150000_add_connection_request/migration.sql`: Non-destructive migration creating `connection_requests` table and foreign keys/indexes.
  - `backend/src/modules/matching/matching.service.ts`:
    - Updated `getDiscoverFeed` to filter out users with active pending requests in either direction.
    - Updated `recordSwipe`: on `LIKE`, creates `ConnectionRequest` with status `PENDING` in the same transaction (rely on `@@unique([senderPetId, receiverPetId])`, catch `P2002`).
    - Added `getIncomingRequests`: returns pending requests for receiver with sender username, pet photo, breed, receiver pet name, and total `pendingCount`.
    - Added `acceptConnectionRequest`: verifies receiver identity, checks `PENDING`, uses atomic `updateMany` concurrency guard, returns `{ requestId, status: "ACCEPTED", matchId: null }`.
    - Added `rejectConnectionRequest`: verifies receiver identity, checks `PENDING`, uses atomic `updateMany` concurrency guard, returns `{ requestId, status: "REJECTED" }`.
  - `backend/src/modules/matching/matching.controller.ts`: Controllers `getIncomingRequests`, `postAcceptRequest`, and `postRejectRequest`.
  - `backend/src/modules/matching/matching.routes.ts`: Routes `GET /requests/incoming`, `POST /requests/:id/accept`, `POST /requests/:id/reject`.
  - `backend/test/matching.test.ts`: Unit tests for `RequestStatus` enum, 404 on missing request, 409 double-action guard, and 403 on non-receiver.
- **Frontend**:
  - `lib/core/services/api_client.dart`: Updated `postMultipart` to read bytes safely and use `http.MultipartFile.fromBytes` instead of `fromPath` (resolves `Unsupported operation: MultipartFile is only supported where dart:io is available` across web/desktop/mobile).
  - `lib/core/services/cloudinary_service.dart`: Added support for optional `bytes` and `filename` in image uploads.
  - `lib/features/home/data/models/connection_request_model.dart`: Models `ConnectionRequestModel` and `IncomingRequestsResult`.
  - `lib/features/home/data/repositories/matching_repository.dart`: Extended repository with `getIncomingRequests`, `acceptRequest`, and `rejectRequest`.
  - `lib/features/home/presentation/providers/requests_provider.dart`: Riverpod `Notifier` managing `RequestsState` (`requests`, `pendingCount`, `isLoading`, `actionLoadingIds`, `errorMessage`), optimistic removals on accept/reject, double-action prevention via `actionLoadingIds`, and 409 conflict handling.
  - `lib/features/home/presentation/pages/requests_page.dart`: Requests list screen with pending count header, pull-to-refresh, empty state, card rendering (pet image with Cloudinary transformations via `AppNetworkImage`, breed, sender username, target pet name), per-item loading spinner, and Decline/Accept action buttons.
  - `lib/features/home/presentation/widgets/bottom_nav_bar.dart`: Added `pendingRequestsCount` badge to Tab 1 (Requests) when count > 0.
  - `lib/features/home/presentation/pages/home_page.dart`: Wired Tab 1 to `RequestsPage`, bottom nav badge with `requestsState.pendingCount`, tab switch refresh, and app resume refresh via `WidgetsBindingObserver`.
  - `test/requests_test.dart`: Flutter unit tests for loading requests, accept removal & count decrement, reject removal, double-tap prevention (`actionLoadingIds`), and 409 conflict handling.
  - `test/discover_test.dart` & `test/auth_flow_test.dart`: Updated mock repositories with new interface methods.

### 2. Prisma Models & Fields Implemented
```prisma
enum RequestStatus {
  PENDING
  ACCEPTED
  REJECTED
}

model ConnectionRequest {
  id             String        @id @default(uuid())
  senderUserId   String        @map("sender_user_id")
  senderPetId    String        @map("sender_pet_id")
  receiverUserId String        @map("receiver_user_id")
  receiverPetId  String        @map("receiver_pet_id")
  status         RequestStatus @default(PENDING)
  createdAt      DateTime      @default(now()) @map("created_at")
  respondedAt    DateTime?     @map("responded_at")

  senderUser   User @relation("RequestsSent", fields: [senderUserId], references: [id], onDelete: Cascade)
  receiverUser User @relation("RequestsReceived", fields: [receiverUserId], references: [id], onDelete: Cascade)
  senderPet    Pet  @relation("PetRequestsSent", fields: [senderPetId], references: [id], onDelete: Cascade)
  receiverPet  Pet  @relation("PetRequestsReceived", fields: [receiverPetId], references: [id], onDelete: Cascade)

  @@unique([senderPetId, receiverPetId])
  @@index([receiverUserId, status])
  @@index([senderUserId])
  @@map("connection_requests")
}
```

### 3. Endpoint Contracts Implemented

#### `GET /api/requests/incoming`
- **Query Parameters**:
  - `cursor` (optional string): Pagination cursor.
  - `limit` (optional integer, default 20, max 50).
- **Security**: Requires verified Firebase ID token. Returns only pending requests where caller is `receiverUserId`.
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Incoming connection requests retrieved successfully",
  "data": {
    "requests": [
      {
        "id": "req-uuid",
        "senderUserId": "sender-user-uuid",
        "senderUsername": "sneha_s",
        "senderPetId": "sender-pet-uuid",
        "senderPetName": "Bella",
        "senderPetImageUrl": "https://res.cloudinary.com/.../pet.jpg",
        "senderPetBreed": "Golden Retriever",
        "receiverPetId": "receiver-pet-uuid",
        "receiverPetName": "Milo",
        "status": "PENDING",
        "createdAt": "2026-11-18T12:00:00.000Z"
      }
    ],
    "nextCursor": null,
    "hasMore": false,
    "pendingCount": 1
  }
}
```

#### `POST /api/requests/:id/accept`
- **Security**: Caller must be `receiverUserId`. Status must be `PENDING`.
- **Concurrency**: Guarded with `updateMany` (`count === 1`).
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Connection request accepted successfully",
  "data": {
    "requestId": "req-uuid",
    "status": "ACCEPTED",
    "matchId": null
  }
}
```

#### `POST /api/requests/:id/reject`
- **Security**: Caller must be `receiverUserId`. Status must be `PENDING`.
- **Concurrency**: Guarded with `updateMany` (`count === 1`).
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Connection request rejected successfully",
  "data": {
    "requestId": "req-uuid",
    "status": "REJECTED"
  }
}
```

### 4. Flutter Classes & Providers
- `ConnectionRequestModel` & `IncomingRequestsResult` ([connection_request_model.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/data/models/connection_request_model.dart))
- `MatchingRepository` ([matching_repository.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/data/repositories/matching_repository.dart)): Added `getIncomingRequests`, `acceptRequest`, `rejectRequest`.
- `RequestsState` & `RequestsNotifier` / `requestsProvider` ([requests_provider.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/presentation/providers/requests_provider.dart)): Riverpod notifier with loading, accept/reject, action lock IDs, and optimistic removal.
- `RequestsPage` ([requests_page.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/presentation/pages/requests_page.dart)): Full requests management view with Decline & Accept buttons, per-item spinner, and pull-to-refresh.
- `PetMateBottomNavBar` ([bottom_nav_bar.dart](file:///d:/L5%20SEM_3_2026/petmatee/lib/features/home/presentation/widgets/bottom_nav_bar.dart)): Badge showing unread pending requests count.

### 5. Hooks Left for Part 3
- In `backend/src/modules/matching/matching.service.ts`:
  - `// PART 3 HOOK: also exclude users with a match`: In `getDiscoverFeed` exclusion query.
  - `// PART 3 HOOK: mutual like -> auto-accept + match`: In `recordSwipe`.
  - `// PART 3 HOOK: create Match in the same transaction`: In `acceptConnectionRequest`.
- In `lib/features/home/presentation/providers/requests_provider.dart` & `requests_page.dart`:
  - `// PART 3 HOOK: navigate to chat window`: Called inside `onAccepted`.

### 6. Verification Status
- Backend TypeScript (`npm run typecheck`): 0 errors.
- Backend test suite (`npx tsx --test test/*.test.ts`): 19 passed, 0 failed.
- Flutter analyzer (`dart analyze lib/ test/`): 0 errors, 0 warnings.
- Flutter test suite (`flutter test`): 24 passed, 0 failed.

