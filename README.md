# PetMate 🐾

> **An all-in-one multi-role pet care and pet services platform.**  
> Connects pet owners, veterinarians, sellers, and event organizers in a unified, modern mobile ecosystem.

[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Express](https://img.shields.io/badge/Express-5.x-000000?logo=express&logoColor=white)](https://expressjs.com)
[![Prisma](https://img.shields.io/badge/Prisma-7.x-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org)

---

## 📖 Overview

**PetMate** simplifies pet parenting by bringing essential pet-related services together under one roof. Instead of relying on disparate channels for breeding connections, veterinary consultations, supplies, and community gatherings, PetMate delivers a secure, role-based platform designed with an initial focus on the Nepalese market.

### Key Highlights
- **Pet Dating & Matching:** Swipe-based matching ("Mating to Dating") for pet breeding and playdates with two-way consent verification.
- **Veterinary Appointments:** Discover certified veterinarians, check real-time availability slots, and book non-conflicting consultations.
- **Multi-Vendor Marketplace:** Shop verified pet food, supplements, and accessories with server-enforced pricing.
- **Community Events:** Register and participate in pet competitions, vaccination drives, and meetups with capacity tracking.
- **End-to-End Security:** JWT authentication, strict role-based access control (RBAC), and server-verified workflows.

---

## 👥 User Roles & Permissions

PetMate operates on a granular multi-role authorization model:

| Role | Primary Responsibilities & Capabilities |
| :--- | :--- |
| **Pet Owner** | Manage pet profiles, discover pet partners via swipe matching, chat with confirmed matches, browse & buy products, schedule vet visits, and sign up for community events. |
| **Seller** | Manage pet supply store profiles, publish product listings, track inventory, and process incoming customer orders upon admin verification. |
| **Veterinarian** | Set up clinical profiles and credentials, manage availability schedules, specify consultation charges, and conduct booked appointments once verified. |
| **Administrator** | Moderate platform content, verify seller applications and veterinarian licenses, monitor transactions, oversee platform statistics, and enforce account suspensions. |

---

## 🛠️ Technology Stack

### Mobile Client (Flutter)
- **Framework:** Flutter (Stable channel) with Dart 3
- **Architecture:** Feature-first modular organization
- **State Management:** [Riverpod 3](https://riverpod.dev) (`Notifier` / `NotifierProvider`)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router)
- **Networking:** HTTP Client with typed error envelopes and automated JWT Bearer token injection
- **Persistence:** `shared_preferences` for secure local session caching
- **UI System:** Material 3 with customized PetCare design tokens

### Backend API (Node.js & TypeScript)
- **Runtime & Language:** Node.js with TypeScript (`tsx` runtime execution)
- **Web Framework:** Express.js 5
- **ORM & Database:** Prisma ORM 7 with PostgreSQL (leveraging `@prisma/adapter-pg`)
- **Authentication:** JSON Web Tokens (JWT) & `bcryptjs` password hashing
- **File & Media Storage:** Cloudinary (secure server-side asset handling)
- **Real-Time Communication:** Socket.IO for real-time messaging

---

## 📂 Repository Structure

The project is maintained as a cohesive monorepo with the Flutter mobile application at the root and the TypeScript backend service encapsulated in `backend/`:

```
petmatee/
├── android/                         # Native Android platform configurations
├── backend/                         # Node.js TypeScript API service
│   ├── prisma/
│   │   ├── migrations/              # Database migration history
│   │   └── schema.prisma            # Prisma schema models & enums
│   ├── src/
│   │   ├── config/                  # Environment and database client configs
│   │   │   ├── db.ts                # PrismaClient instance
│   │   │   └── env.ts               # Typed environment loader
│   │   ├── generated/prisma/        # Generated Prisma Client
│   │   ├── middleware/              # Auth & error handling middlewares
│   │   │   ├── auth.middleware.ts   # JWT & role authorization guards
│   │   │   └── errorHandler.ts      # Centralized error handler
│   │   ├── modules/                 # Modular feature domains
│   │   │   └── auth/                # Authentication module
│   │   │       ├── auth.controller.ts
│   │   │       ├── auth.routes.ts
│   │   │       ├── auth.service.ts
│   │   │       ├── auth.types.ts
│   │   │       └── auth.validation.ts
│   │   ├── utils/                   # Standard API response builders
│   │   ├── app.ts                   # Express application setup
│   │   └── server.ts                # Server entry point & graceful shutdown
│   ├── package.json
│   ├── prisma7.config.ts
│   └── tsconfig.json
├── lib/                             # Flutter mobile application
│   ├── core/                        # Shared cross-cutting infrastructure
│   │   ├── config/                  # App constants & platform-aware API base URLs
│   │   ├── constants/               # Color palettes & UI tokens
│   │   ├── errors/                  # Typed exception definitions
│   │   ├── router/                  # GoRouter configuration
│   │   ├── services/                # ApiClient & StorageService
│   │   └── theme/                   # Material 3 theme data
│   ├── features/                    # Feature-first slices
│   │   ├── auth/                    # Auth data, domain & presentation
│   │   └── home/                    # Landing dashboard & platform navigation
│   ├── app.dart                     # Root ConsumerWidget
│   └── main.dart                    # Application entry point & ProviderScope setup
├── test/                            # Unit & widget tests
└── pubspec.yaml                     # Flutter dependencies
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.47+ recommended)
- [Node.js](https://nodejs.org) (v20+ or v24+) & `npm`
- [PostgreSQL](https://www.postgresql.org/download/) (v15+) running locally or remotely

---

### 1. Backend Setup

1. **Navigate to the backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Configure Environment Variables:**  
   Create or verify `.env` in `backend/.env`:
   ```env
   PORT=5000
   NODE_ENV=development
   DATABASE_URL="postgresql://<user>:<password>@localhost:5432/petmate_db?schema=public"
   JWT_SECRET="your_secure_jwt_secret_key"
   JWT_EXPIRES_IN="7d"
   CLOUDINARY_CLOUD_NAME="your_cloud_name"
   CLOUDINARY_API_KEY="your_api_key"
   CLOUDINARY_API_SECRET="your_api_secret"
   ```

4. **Run Database Migrations & Generate Prisma Client:**
   ```bash
   npx prisma migrate dev
   npx prisma generate
   ```

5. **Start the Development Server:**
   ```bash
   npm run dev
   ```
   - Server runs at: `http://localhost:5000`
   - Health check: `http://localhost:5000/api/v1/health`

---

### 2. Mobile App Setup (Flutter)

1. **Navigate to the repository root:**
   ```bash
   cd ..
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Verify API Base URL:**  
   In `lib/core/config/app_config.dart`, PetMate automatically routes requests:
   - **Android Emulator:** `http://10.0.2.2:5000/api/v1`
   - **Web / Desktop / iOS Simulator:** `http://localhost:5000/api/v1`
   - *Physical devices: Update with your local machine's IP address (e.g., `http://192.168.x.x:5000/api/v1`).*

4. **Launch the application:**
   ```bash
   flutter run
   ```

---

## 📡 API Conventions

All API routes follow standard RESTful conventions prefixed by `/api/v1`.

### Response Envelopes

#### ✅ Success Response (`200 OK`, `201 Created`)
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {
    "user": {
      "id": "6f26ba44-b606-4cfa-84a2-fc67f4963bea",
      "email": "user@example.com",
      "fullName": "Jane Doe",
      "role": "PET_OWNER",
      "status": "ACTIVE"
    },
    "token": "eyJhbGciOi..."
  }
}
```

#### ❌ Error Response (`400`, `401`, `403`, `404`, `409`, `500`)
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    "Password must be at least 6 characters long"
  ]
}
```

### Core Auth Endpoints
| Method | Endpoint | Access | Description |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/v1/health` | Public | System status and health monitor |
| `POST` | `/api/v1/auth/register` | Public | Register new `PET_OWNER`, `SELLER`, or `VETERINARIAN` |
| `POST` | `/api/v1/auth/login` | Public | Authenticate user and obtain JWT |
| `GET` | `/api/v1/auth/me` | Bearer Token | Fetch authenticated user profile |

---

## 🔒 Security & Business Rules

1. **Strict Role Isolation:** Public registration is restricted to `PET_OWNER`, `SELLER`, and `VETERINARIAN`. Initial `ADMIN` accounts are provisioned via secure administrative seed scripts.
2. **Consent-Gated Matching:** A right-swipe indicates interest. Both owners must accept before a match is confirmed and real-time chat unlocks.
3. **Double-Booking Prevention:** Veterinary booking slots are verified via transactional locking to eliminate race conditions.
4. **Server-Side Financial Calculations:** Product prices and order totals are calculated exclusively on the backend from trusted database state.
5. **Session Safety:** Suspended accounts are immediately blocked at the authentication middleware level.

---

## 🧪 Testing

### Mobile Tests
```bash
# Analyze code quality and formatting
flutter analyze

# Execute Flutter widget and unit tests
flutter test
```

### Backend Type Check & Tests
```bash
cd backend

# Run TypeScript type verification
npm run typecheck
```

---

## 🤝 Development & Contribution Guidelines

1. **Branching Strategy:** Work on designated feature branches (`feature/<name>`) and coordinate Prisma schema changes before applying migrations.
2. **Secrets Protection:** Never commit `.env` or production credentials. Use local environment files for development.
3. **Commit Standards:** Write descriptive, imperative commit messages (e.g., `feat(auth): add role validation to registration flow`).

---

## 📄 License

This project is developed under an academic and proprietary license for PetMate. All rights reserved.
