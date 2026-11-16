import { Router } from "express";
import { register, login, getProfile } from "./auth.controller.js";
import { validateRegisterInput, validateLoginInput } from "./auth.validation.js";
import { authenticate } from "../../middleware/auth.middleware.js";

const router = Router();

router.post("/register", validateRegisterInput, register);
router.post("/login", validateLoginInput, login);
router.get("/me", authenticate, getProfile);

export default router;
