import { AppError } from "../../middleware/errorHandler.js";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ALLOWED_REGISTER_ROLES = ["PET_OWNER", "SELLER", "VETERINARIAN"];

export const validateRegisterInput = (req, res, next) => {
  const { email, password, fullName, phoneNumber, role } = req.body;
  const errors = [];

  if (!email || typeof email !== "string" || !EMAIL_REGEX.test(email.trim())) {
    errors.push("A valid email address is required");
  }

  if (!password || typeof password !== "string" || password.length < 6) {
    errors.push("Password must be at least 6 characters long");
  }

  if (!fullName || typeof fullName !== "string" || fullName.trim().length === 0) {
    errors.push("Full name is required");
  }

  if (role) {
    if (role === "ADMIN") {
      errors.push("Admin accounts cannot be registered through public registration");
    } else if (!ALLOWED_REGISTER_ROLES.includes(role)) {
      errors.push(`Invalid role. Allowed roles are: ${ALLOWED_REGISTER_ROLES.join(", ")}`);
    }
  }

  if (errors.length > 0) {
    return next(new AppError("Validation failed", 400, errors));
  }

  req.body.email = email.trim().toLowerCase();
  req.body.fullName = fullName.trim();
  if (phoneNumber && typeof phoneNumber === "string") {
    req.body.phoneNumber = phoneNumber.trim();
  }
  if (!req.body.role) {
    req.body.role = "PET_OWNER";
  }

  next();
};

export const validateLoginInput = (req, res, next) => {
  const { email, password } = req.body;
  const errors = [];

  if (!email || typeof email !== "string" || !EMAIL_REGEX.test(email.trim())) {
    errors.push("A valid email address is required");
  }

  if (!password || typeof password !== "string" || password.length === 0) {
    errors.push("Password is required");
  }

  if (errors.length > 0) {
    return next(new AppError("Validation failed", 400, errors));
  }

  req.body.email = email.trim().toLowerCase();
  next();
};
