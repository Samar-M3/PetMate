# PETMATE – Product Requirements Document (PRD)

**Project Name:** PetMate
**Project Type:** Pet Care and Pet Services Mobile Application
**Target Platform:** Android
**Initial Market:** Nepal
**Status:** In Development

---

# 1. Project Overview

PetMate is an all-in-one pet care platform designed to connect pet owners, veterinarians, sellers, and event organizers in a single application.

The application aims to make pet ownership easier by providing services such as pet matching, veterinary appointments, online shopping, event participation, and communication between pet owners.

Instead of using multiple applications for different pet-related services, users can access these services through one platform.

PetMate will operate as a multi-role platform where different users have different permissions and capabilities.

# 2. Project Objectives

- Provide a platform for pet owners to manage their pets.
- Allow pet owners to discover and connect with potential pet partners.
- Provide an online marketplace for pet-related products.
- Allow users to discover veterinarians and book appointments.
- Provide a platform for pet-related events and registrations.
- Enable real-time communication between matched pet owners.
- Provide administrators with tools to manage and monitor the platform.

# 3. User Roles

The application will support the following roles:

### 3.1 Pet Owner

The primary application user.

Capabilities:

- Register and log in.
- Manage personal profile.
- Create and manage pet profiles.
- Discover and like other pets.
- Send and receive matching requests.
- Chat with owners after a successful match.
- Browse and purchase products.
- Book veterinary appointments.
- Browse and register for events.

### 3.2 Seller

A user who sells pet-related products through PetMate.

Capabilities:

- Create a seller profile.
- Submit seller information for verification.
- Manage store information.
- Create, update, and delete product listings.
- Upload product images.
- Manage incoming orders.
- View order and payment statuses.

Seller accounts must be approved by an administrator before they can sell products.

### 3.3 Veterinarian

A veterinary professional who provides services through PetMate.

Capabilities:

- Create a veterinarian profile.
- Submit professional information and qualifications.
- Set consultation charges.
- Manage specialization and experience details.
- Manage appointment availability.
- View and manage appointment requests.
- View appointment history.

Veterinarian accounts must be verified by an administrator before accepting appointments.

Administrators create veterinarian login accounts with a temporary password. On first login, the veterinarian must set a new password before using veterinarian features; the temporary password cannot be reused.

### 3.4 Administrator

Responsible for managing and monitoring the platform.

Capabilities:

- View platform statistics.
- Manage users and account statuses.
- Approve or reject seller applications.
- Verify veterinarians.
- Moderate product listings.
- Monitor orders and transactions.
- Manage veterinary appointments.
- Manage events and registrations.
- Review reported or inappropriate content.
- Perform administrative actions and monitor activity logs.

Administrators must not be able to register through the normal public registration process. Initial administrator accounts must be created through a secure setup or database seed process.

# 4. Core Features and Functional Requirements

## 4.1 Authentication and User Management

Users should be able to create accounts and securely access the application.

Features:

- User registration.
- User login and logout.
- Password hashing.
- JWT-based authentication.
- Authentication middleware.
- Role-based authorization.
- User profile management.
- Profile image upload using Cloudinary.
- Account activation and suspension.

The backend must verify user roles before allowing access to protected features.

## 4.2 Pet Profile Management

Pet owners should be able to create and manage profiles for their pets.

Pet profile information may include:

- Pet name.
- Species.
- Breed.
- Gender.
- Date of birth or age.
- Weight.
- Description.
- Location.
- Multiple images.
- Vaccination information.
- Other relevant health information.

Features:

- Create pet profile.
- View pet profiles.
- Update pet information.
- Delete pet profiles.
- Upload and manage pet images.
- Associate each pet with its owner.

A user may own multiple pets.

## 4.3 Pet Matching – Mating to Dating

This feature allows pet owners to discover potential partners for their pets through a swipe-based interface.

The interaction should be similar to a dating application.

Features:

- Display discoverable pet profiles.
- Swipe right to like a pet.
- Swipe left to reject or skip a pet.
- Prevent users from discovering their own pets.
- Exclude pets that the current user has already interacted with.
- Store swipe history.
- Create a match request when an owner likes another pet.
- Notify the receiving owner about the request.
- Allow the receiving owner to accept or reject the request.

### Matching Workflow

1. Owner A discovers Owner B's pet.
2. Owner A swipes right.
3. The backend creates a pending match request.
4. Owner B receives the request.
5. Owner B can accept or reject it.
6. If accepted, the match becomes confirmed.
7. A chat conversation becomes available to both owners.

**Important business rule:** A right swipe alone must not create a confirmed match. Both owners must agree before chatting becomes available.

## 4.4 Chat System

The chat system allows pet owners to communicate after successfully matching.

Features:

- View a list of conversations.
- Open a conversation.
- Send and receive messages.
- Display message timestamps.
- Display message history.
- Support real-time communication.
- Restrict chat access to confirmed matches.

The backend must verify that the authenticated user belongs to the confirmed match before allowing access to its conversation.

Suggested technology: Socket.IO for real-time messaging.

## 4.5 E-commerce Marketplace

PetMate will provide a multi-vendor marketplace similar to platforms such as Daraz.

Sellers will manage their own stores and product listings. PetMate will provide the marketplace infrastructure.

### Buyer Features

- Browse products.
- Search products.
- Filter products by category.
- View product details.
- View product images, descriptions, and prices.
- Add products to cart.
- Update cart quantities.
- Checkout.
- Place orders.
- View order history.
- Track order status.

### Seller Features

- Create and manage seller profile.
- Submit seller application for approval.
- Create product listings.
- Upload product images.
- Update product information.
- Manage product availability and stock.
- View incoming orders.
- Update order fulfillment status.

### Product Information

A product should contain:

- Product name.
- Description.
- Price.
- Category.
- Product images.
- Stock quantity.
- Seller reference.
- Product status.

### Order Workflow

1. Buyer adds products to cart.
2. Buyer proceeds to checkout.
3. Backend calculates the order total using trusted database prices.
4. Buyer initiates payment.
5. Backend verifies the payment result.
6. Order is confirmed after successful payment.
7. Seller can view and process the order.
8. Buyer can view the order status.

The backend must never trust product prices or order totals submitted directly by the client.

## 4.6 Veterinary Appointment System

Pet owners should be able to discover veterinarians and book appointments through the application.

### Pet Owner Features

- Browse available veterinarians.
- Search or filter veterinarians.
- View veterinarian profiles.
- View specialization and experience.
- View consultation charges.
- View available appointment slots.
- Select a pet.
- Book an appointment.
- Complete payment.
- View appointment history.
- View appointment status.

### Veterinarian Features

- Manage professional profile.
- Add specialization and experience.
- Set consultation fees.
- Manage availability.
- View appointment requests.
- Accept, reject, or manage appointments.
- View appointment history.

### Veterinarian Profile Information

- Full name.
- Profile image.
- Qualification and credentials.
- Specialization.
- Experience.
- Clinic or workplace information.
- Consultation charges.
- Availability.
- Verification status.

### Appointment Workflow

1. Pet owner selects a veterinarian.
2. Pet owner selects one of their registered pets.
3. Pet owner selects an available date and time.
4. Backend validates the selected slot.
5. Appointment payment is initiated.
6. Payment is verified by the backend.
7. Appointment is confirmed according to the booking rules.
8. Both parties can view the appointment details.

**Important:** The backend must prevent two users from booking the same veterinarian's appointment slot.

## 4.7 Events and Event Booking

PetMate will provide a section where users can discover and participate in pet-related events.

Events may include:

- Pet shows.
- Pet meetups.
- Training sessions.
- Awareness programs.
- Pet competitions.
- Other pet-related activities.

### User Features

- Browse events.
- View event details.
- View event date, time, and location.
- View event descriptions and posters.
- Identify free and paid events.
- Register for free events.
- Book paid events.
- View registered events.

### Event Organizer / Admin Features

For the initial MVP, event creation and management will be handled by administrators.

Capabilities:

- Create events.
- Update event information.
- Upload event posters.
- Set event capacity.
- Set event fees.
- Publish or cancel events.
- View event registrations.

### Event Booking Workflow

1. User selects an event.
2. User views event information.
3. User registers for a free event or initiates payment for a paid event.
4. Backend validates event availability and capacity.
5. Registration is created.
6. Paid registration is confirmed after successful payment.
7. User can view registration details.

## 4.8 Admin Dashboard and Platform Management

Administrators will have access to a protected dashboard.

### Dashboard

Display important platform statistics:

- Total users.
- Total pet owners.
- Total sellers.
- Total veterinarians.
- Total products.
- Total orders.
- Total appointments.
- Total events.
- Revenue and transaction summaries.
- Recent platform activities.

### User Management

- View users.
- Search and filter users.
- View user details.
- Activate or suspend accounts.
- Manage user roles where permitted.

### Seller Management

- View seller applications.
- Review seller information.
- Approve or reject applications.
- Suspend or reactivate sellers.

### Veterinarian Management

- View veterinarian applications.
- Review professional credentials.
- Verify or reject applications.
- Suspend or reactivate veterinarians.

### Marketplace Management

- View product listings.
- Remove inappropriate products.
- Monitor sellers.
- View orders and payment statuses.

### Appointment Management

- View all appointments.
- Monitor appointment statuses.
- View veterinarian and pet owner details.

### Event Management

- Create and update events.
- Publish and cancel events.
- View event registrations.
- Monitor event capacity.

### Moderation

- Review reported content or profiles.
- Take appropriate moderation actions.
- Record reasons for administrative actions.

# 5. Payment Requirements

PetMate will support payments for:

- Marketplace orders.
- Veterinary appointments.
- Paid event registrations.

The application will use a payment gateway suitable for the Nepalese market.

**Payment gateway: To be finalized.**

Potential options include Khalti or eSewa, subject to availability, integration requirements, and project approval.

Payment requirements:

- Payment initiation must happen through the backend.
- Payment credentials must remain on the server.
- Payment results must be verified server-side.
- Store gateway transaction references.
- Prevent duplicate payment processing.
- Maintain transaction statuses.
- Confirm the associated order, appointment, or registration only after verified payment success.

Do not assume that a successful payment redirect from Flutter is sufficient proof of payment.

# 6. Technology Stack

| Layer                | Technology                                 |
| -------------------- | ------------------------------------------ |
| Mobile application   | Flutter                                    |
| Programming language | Dart                                       |
| State management     | Riverpod                                   |
| Navigation           | GoRouter                                   |
| Backend runtime      | Node.js                                    |
| Backend framework    | Express.js                                 |
| Backend language     | JavaScript or TypeScript (to be finalized) |
| Database             | PostgreSQL                                 |
| ORM                  | Prisma                                     |
| Image storage        | Cloudinary                                 |
| Authentication       | JWT                                        |
| Password hashing     | bcrypt                                     |
| Real-time chat       | Socket.IO                                  |
| API documentation    | Swagger / OpenAPI                          |
| Payment gateway      | TBD                                        |

# 7. Non-Functional Requirements

### Security

- Hash passwords before storing them.
- Use JWT authentication.
- Implement role-based access control.
- Validate all incoming requests.
- Protect sensitive endpoints.
- Store secrets in environment variables.
- Verify payment transactions on the backend.
- Prevent unauthorized access to chat conversations.
- Apply database constraints where appropriate.

### Performance

- Use pagination for large datasets.
- Optimize database queries.
- Compress and optimize uploaded images.
- Avoid unnecessary API requests.
- Use efficient state management in Flutter.

### Reliability

- Handle API failures gracefully.
- Validate data on both client and server.
- Prevent duplicate bookings and payment processing.
- Use database transactions for operations that must succeed together.

### Maintainability

- Use modular architecture.
- Keep business logic separate from controllers and UI.
- Use reusable Flutter widgets.
- Maintain consistent API response formats.
- Document backend endpoints using Swagger.

# 8. MVP Scope

The initial version should prioritize functional implementation of:

1. Authentication and role management.
2. Pet profile management.
3. Pet matching and match requests.
4. Chat after confirmed matches.
5. Multi-vendor product marketplace.
6. Cart and order management.
7. Veterinarian profiles and appointments.
8. Events and event registrations.
9. Payment integration.
10. Basic admin dashboard and management.

Advanced analytics, complex recommendation algorithms, advanced reporting, and other non-essential features can be considered future enhancements.

# 9. Important Business Rules

- A user can own multiple pets.
- Users cannot match their own pets.
- A pet should not repeatedly appear to the same owner after being swiped.
- A match is confirmed only after the receiving owner accepts.
- Chat is available only to owners of confirmed matches.
- Only approved sellers can publish products.
- Only verified veterinarians can accept appointments.
- Product prices must be calculated by the backend.
- Appointment slots must not be double-booked.
- Event capacity must be respected.
- Paid orders, appointments, and event registrations require verified payment.
- Admin accounts must be created securely, not through public registration.
- Admin-only operations must be protected on the backend.

# 10. Future Enhancements

Possible future features:

- Community feed for pet owners.
- Pet vaccination reminders and personalized vaccination recommendations.
- Pet health records.
- Push notifications.
- Reviews and ratings for sellers and veterinarians.
- Advanced pet matching recommendations.
- Order delivery tracking.
- More advanced admin analytics.

These are future enhancements unless explicitly added to the current development scope.
