import { Router } from "express";
import { register, login, getProfile } from "./auth.controller.ts";
import { validateRegisterInput, validateLoginInput } from "./auth.validation.ts";
import { authenticate } from "../../middleware/auth.middleware.ts";

const router = Router();

router.post("/register", validateRegisterInput, register);
router.post("/login", validateLoginInput, login);
router.get("/me", authenticate, getProfile);

export default router;
