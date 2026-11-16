PETMATE – AI DEVELOPMENT INSTRUCTIONS
You are working on PetMate, a multi-role pet care platform.

Before making any code changes, read PROJECT_CONTEXT.md to understand the product requirements, features, user roles, and business rules.

Your responsibility is to help build a clean, maintainable, secure, and functional application.
1. Current Project Structure
The following is the existing structure observed in the repository. Treat it as the source of truth. Do not replace it with a generic mobile/ + backend/ template.
PETMATE/
├── .dart_tool/                  # Flutter/Dart tooling
├── .idea/                       # IDE configuration
├── android/                     # Flutter Android platform
├── backend/
│   ├── .agents/                 # Agent configuration
│   ├── .claude/                 # Claude configuration
│   ├── .windsurf/               # Windsurf configuration
│   ├── node_modules/            # Backend dependencies
│   ├── prisma/                  # Prisma schema/migrations; inspect contents before editing
│   ├── src/
│   │   ├── generated/
│   │   │   └── prisma/          # Generated Prisma Client (do not hand-edit)
│   │   │       ├── internal/
│   │   │       ├── models/
│   │   │       ├── browser.ts
│   │   │       ├── client.ts
│   │   │       ├── commonInputTypes.ts
│   │   │       ├── enums.ts
│   │   │       └── models.ts
│   │   └── test-db.js
│   ├── .env                     # Local secrets/configuration; never commit or expose
│   ├── .gitignore
│   ├── package-lock.json
│   ├── package.json
│   ├── prisma7.config.ts
│   └── skills-lock.json
├── lib/                         # Flutter application source
│   ├── app.dart
│   └── main.dart
└── node_modules/                # Root-level dependencies
This tree records the items visible in the current project explorer. Some directories (including backend/prisma/) are present but their contents were not visible when this structure was documented. Inspect them before assuming which files they contain.

Important structure rules:
- The Flutter application currently lives at the repository root, with its Dart source in lib/. Do not create a mobile/ directory or move Flutter files unless explicitly requested.
- The Node.js backend lives in backend/. Keep backend source, dependencies, configuration, and Prisma files inside that directory.
- Do not create a second backend folder, a second src/ folder, or duplicate configuration/package files.
- Before creating a file or folder, inspect the relevant directory and search for an existing implementation with the same responsibility.
- Extend the current structure incrementally. Do not generate every folder from a recommended architecture in advance.
- The tree is a snapshot, not permission to delete, rename, move, or restructure existing files.
2. Technology Requirements
Flutter
- Flutter stable channel.
- Dart.
- Riverpod for state management.
- GoRouter for navigation.
- Freezed and json_serializable for model generation where useful.
- Follow feature-first architecture.
- Use reusable widgets and shared components.
- Separate UI from business logic and data access.
Backend
- Node.js.
- Express.js.
- PostgreSQL.
- Prisma ORM.
- Cloudinary for image uploads.
- JWT authentication.
- bcrypt for password hashing.
- Socket.IO for real-time chat.
- Swagger / OpenAPI for API documentation.
Use TypeScript for new backend code if the project has not already established a JavaScript convention. Do not migrate an existing JavaScript codebase to TypeScript without discussing the impact first.
3. Flutter Architecture
Use feature-first organization.

Recommended structure:
mobile/
└── lib/
    ├── main.dart
    ├── app.dart
    │
    ├── core/
    │   ├── config/
    │   ├── constants/
    │   ├── errors/
    │   ├── router/
    │   ├── services/
    │   ├── theme/
    │   ├── utils/
    │   └── widgets/
    │
    ├── features/
    │   ├── auth/
    │   ├── profile/
    │   ├── pets/
    │   ├── matching/
    │   ├── chat/
    │   ├── marketplace/
    │   ├── appointments/
    │   ├── events/
    │   └── admin/
    │
    └── shared/
Each feature should contain only the layers it needs.

Suggested feature structure:
feature_name/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   └── repositories/
│
└── presentation/
    ├── pages/
    ├── widgets/
    └── providers/
Do not create unnecessary abstractions or empty files just to follow the structure.
4. Backend Architecture
Existing backend layout
The backend is located in backend/. Its currently observed structure is:
backend/
├── .agents/
├── .claude/
├── .windsurf/
├── node_modules/
├── prisma/
├── src/
│   ├── generated/
│   │   └── prisma/              # Generated Prisma Client
│   │       ├── internal/
│   │       ├── models/
│   │       ├── browser.ts
│   │       ├── client.ts
│   │       ├── commonInputTypes.ts
│   │       ├── enums.ts
│   │       └── models.ts
│   └── test-db.js
├── .env
├── .gitignore
├── package-lock.json
├── package.json
├── prisma7.config.ts
└── skills-lock.json
backend/prisma/ exists, but its contents must be inspected before changing or creating Prisma schema or migration files. Check prisma7.config.ts to confirm the configured schema, migrations, and generated-client locations.
Rules for extending the backend
- backend/src/ is the existing backend source directory. Add backend application code there; do not create another source root such as backend/backend/src/, backend/src/backend/, or a parallel server/ directory.
- backend/src/generated/prisma/ is generated Prisma Client output. Never manually create, edit, duplicate, or move files inside it. Update the actual Prisma schema/configuration and use the project's configured Prisma generation command when regeneration is needed.
- Do not create another Prisma Client output directory or instantiate a second client in a different location. First inspect how the existing generated client is imported and used.
- backend/src/test-db.js already exists. Inspect and reuse or update it if the task concerns database connectivity; do not create another test-db file with a different or duplicate name.
- Before adding routes, controllers, services, middleware, utilities, or modules, inspect backend/src/ and backend/package.json. Add only the files needed for the requested feature.
- Follow the language and module convention already established by the backend. A generated .ts Prisma client does not by itself prove that application code uses TypeScript. Inspect package.json, existing source files, and scripts before choosing JavaScript or TypeScript. Do not migrate conventions without approval.
- Use the existing dependencies and scripts where possible. Do not install a package or create a new config file if the project already has an equivalent.
- Keep .env private. Never print, copy into documentation, commit, or expose its secret values. Update an example environment file only if one is needed and does not already exist.
Target organization (add only when required)
Use modular organization as the backend grows. The following is a possible organization for new feature code, not a directory tree to generate immediately:
backend/src/
├── config/                      # Add if shared configuration is needed
├── middleware/                  # Add if shared middleware is needed
├── utils/                       # Add if shared utilities are needed
├── modules/
│   ├── auth/
│   ├── users/
│   ├── pets/
│   ├── matching/
│   ├── chat/
│   ├── sellers/
│   ├── products/
│   ├── cart/
│   ├── orders/
│   ├── veterinarians/
│   ├── appointments/
│   ├── events/
│   ├── payments/
│   └── admin/
├── app.js or app.ts             # Only if/when the application entry point is needed
└── server.js or server.ts       # Only if/when the server entry point is needed
Do not create both JavaScript and TypeScript versions of the same file. Confirm the project's chosen language and entry-point convention first. Do not create empty modules or placeholder files.

When a module is needed, use this pattern where appropriate:
module_name/
├── module.routes.js             # or .ts, matching the project convention
├── module.controller.js
├── module.service.js
├── module.validation.js
└── module.types.ts              # only when using TypeScript and types are needed
Responsibilities:
- Routes: Define API endpoints and middleware.
- Controllers: Handle HTTP requests and responses.
- Services: Contain business logic.
- Validation: Validate incoming request data.
- Types: Define module-specific types when using TypeScript.
Do not put database queries and complex business logic directly inside route handlers or controllers.
5. Database Guidelines
Use PostgreSQL through Prisma.

Design relationships carefully before implementing database models.

Important entities will include:
- User
- Pet
- PetImage
- Swipe
- Match
- Conversation
- Message
- SellerProfile
- Product
- ProductImage
- Cart
- CartItem
- Order
- OrderItem
- VeterinarianProfile
- VeterinarianAvailability
- Appointment
- Event
- EventRegistration
- PaymentTransaction
- Report
- ModerationAction
- AdminActivityLog
These are conceptual entities, not a requirement to create every table immediately. Refine the schema according to actual feature requirements.

Database rules:
- Use appropriate primary and foreign keys.
- Define Prisma relations correctly.
- Add indexes for frequently queried fields.
- Use unique constraints where required.
- Use enums for controlled statuses where appropriate.
- Store timestamps such as createdAt and updatedAt.
- Use database transactions for related operations.
- Avoid deleting important financial or historical records without a defined retention strategy.
Important constraints
- A user can own multiple pets.
- A pet belongs to one owner.
- A user must not swipe on their own pet.
- A match must have a defined pending, accepted, or rejected state.
- Only accepted matches can access chat.
- A seller must be approved before publishing products.
- A veterinarian must be verified before accepting appointments.
- Appointment booking must prevent overlapping or duplicate bookings.
- Event registrations must respect event capacity.
- Payment gateway references must be stored uniquely where appropriate.
Before creating migrations, inspect the existing Prisma schema and coordinate changes with other developers.

Do not overwrite or reset an existing database to solve migration problems without explicit approval.
6. API Development Standards
Use RESTful API conventions.

Suggested API prefix:
/api/v1
Examples:
POST   /api/v1/auth/register
POST   /api/v1/auth/login

GET    /api/v1/pets
POST   /api/v1/pets
GET    /api/v1/pets/:id
PATCH  /api/v1/pets/:id
DELETE /api/v1/pets/:id

GET    /api/v1/matching/discover
POST   /api/v1/matching/swipes
GET    /api/v1/matching/requests
PATCH  /api/v1/matching/requests/:id

GET    /api/v1/chat/conversations
GET    /api/v1/chat/conversations/:id/messages
POST   /api/v1/chat/conversations/:id/messages

GET    /api/v1/products
POST   /api/v1/products
GET    /api/v1/orders
POST   /api/v1/orders

GET    /api/v1/veterinarians
POST   /api/v1/appointments

GET    /api/v1/events
POST   /api/v1/events/:id/register
These are examples. Confirm endpoint names and request/response contracts before implementing dependent frontend or backend features.
API Response Format
Maintain a consistent response format.

Success:
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {}
}
Error:
{
  "success": false,
  "message": "Validation failed",
  "errors": []
}
Use appropriate HTTP status codes:
- 200: Successful request.
- 201: Resource created.
- 400: Invalid request.
- 401: Unauthenticated.
- 403: Unauthorized.
- 404: Resource not found.
- 409: Conflict.
- 422: Validation error, where applicable.
- 500: Internal server error.
Implement centralized error handling.

Use pagination for endpoints that return potentially large datasets.
7. Authentication and Authorization
- Hash passwords with bcrypt.
- Issue JWTs after successful authentication.
- Verify tokens using authentication middleware.
- Implement role-based authorization middleware.
- Never trust a role supplied by the Flutter client.
- Derive the authenticated user identity from the verified token.
- Protect admin endpoints with server-side role checks.
- Prevent suspended accounts from accessing protected features.
Never expose password hashes, secrets, or private credentials in API responses.
8. Image Uploads
Use Cloudinary for images.

Images may include:
- User profile pictures.
- Pet photos.
- Product images.
- Veterinarian profile images.
- Event posters.
Requirements:
- Validate file type and file size.
- Upload through a secure backend-controlled process.
- Store Cloudinary public IDs and URLs as appropriate.
- Handle failed uploads.
- Remove obsolete Cloudinary assets when appropriate.
- Never expose Cloudinary API secrets in Flutter.
9. Real-Time Chat
Use Socket.IO.

Requirements:
- Authenticate socket connections.
- Verify the user's identity.
- Verify confirmed match membership before allowing conversation access.
- Prevent users from joining unauthorized rooms.
- Persist messages in PostgreSQL.
- Do not rely on socket events as the only source of message storage.
- Support retrieving previous messages through REST APIs.
The backend must enforce conversation permissions even if a client attempts to bypass the Flutter UI.
10. Payment Development Rules
The payment gateway has not yet been finalized.

Do not assume a gateway or create fake payment verification logic.

When payment integration is implemented:
- Keep gateway credentials on the backend.
- Create payment requests through backend APIs.
- Verify payment results server-side.
- Store transaction references and statuses.
- Handle failed, pending, and successful payments.
- Prevent duplicate payment processing.
- Use idempotent payment confirmation logic.
- Confirm the associated order, appointment, or event registration only after verified payment.
Do not mark a transaction successful just because the client reports success.
11. Flutter Development Rules
- Keep widgets focused and reusable.
- Use Riverpod for shared state and asynchronous data.
- Use GoRouter for navigation.
- Separate API calls from presentation widgets.
- Implement loading, success, empty, and error states.
- Validate forms before submission.
- Handle network failures gracefully.
- Avoid hardcoded API URLs throughout the application.
- Keep configuration in a central location.
- Do not put business logic inside large widget build methods.
- Follow consistent naming conventions.
12. Testing Requirements
Write tests for important business logic.

Backend tests should cover:
- Registration and login.
- Authentication and role authorization.
- Pet ownership validation.
- Matching and acceptance workflow.
- Chat access restrictions.
- Product ownership and seller verification.
- Order calculations.
- Appointment availability and double-booking prevention.
- Event capacity and duplicate registrations.
- Payment verification.
- Admin authorization.
Flutter tests should cover:
- Important screens and widgets.
- Form validation.
- Loading and error states.
- Navigation.
- Important user workflows.
Do not claim a feature is complete without testing its important behavior.
13. Swagger Documentation
Document backend APIs using Swagger / OpenAPI.

For each endpoint, document:
- HTTP method and URL.
- Description.
- Authentication requirements.
- Required user role.
- Path and query parameters.
- Request body.
- Success response.
- Error responses.
Keep Swagger documentation updated whenever an endpoint changes.
14. Git and Team Collaboration
Three developers are working on this project.

Before changing shared code:
- Inspect the existing project structure.
- Check the current Git branch and working tree.
- Review existing implementations.
- Avoid overwriting another developer's work.
- Keep changes focused on the assigned feature.
- Coordinate Prisma schema changes and migrations.
- Agree on API contracts before frontend/backend integration.
- Do not commit secrets or .env files.
Use meaningful commit messages.

Do not automatically commit, push, merge, or delete branches unless explicitly instructed.
15. How You Should Work
Whenever a new task is provided:
1. Read PROJECT_CONTEXT.md.
2. Inspect the existing codebase before making changes.
3. Identify which feature and files are affected.
4. Check whether the functionality already exists.
5. Explain the implementation approach briefly.
6. Implement the smallest clean solution that satisfies the requirement.
7. Reuse existing components, services, and patterns.
8. Add validation and error handling.
9. Update relevant documentation.
10. Run appropriate tests or checks.
11. Report the files changed and commands executed.
12. Mention any unresolved issues or required configuration.
Critical Instructions
- Do not rebuild existing functionality without a clear reason.
- Never generate duplicate files or folders. Inspect the current repository tree and search for an existing file with the same purpose before creating anything; extend the existing implementation whenever possible.
- Treat the current project structure documented in Section 1 as authoritative, and update this document if the structure changes.
- Do not introduce unnecessary dependencies.
- Do not invent API endpoints or database fields without considering the existing architecture.
- Do not generate placeholder implementations and describe them as complete.
- Do not bypass backend security for convenience.
- Do not make unrelated changes.
- Do not assume that a frontend feature is functional simply because its UI exists.
- Ask for clarification when a requirement has multiple materially different interpretations.
- Prioritize a working, secure MVP over unnecessary complexity.
Primary Goal: Build PetMate as a functional, reliable, maintainable multi-role pet care platform while keeping the implementation practical for a small development team.