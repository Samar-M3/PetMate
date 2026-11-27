import { Router } from "express";
import { register, login } from "./auth.controller.ts";

const router = Router();

// Rate limiting can be applied here or via global middleware
router.post("/register", register);
router.post("/login", login);

export default router;
