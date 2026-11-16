import { registerUser, loginUser, getCurrentUserProfile } from "./auth.service.js";
import { sendSuccess } from "../../utils/apiResponse.js";

export const register = async (req, res, next) => {
  try {
    const result = await registerUser(req.body);
    return sendSuccess(res, {
      statusCode: 201,
      message: "User registered successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const login = async (req, res, next) => {
  try {
    const result = await loginUser(req.body);
    return sendSuccess(res, {
      statusCode: 200,
      message: "Login successful",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getProfile = async (req, res, next) => {
  try {
    const profile = await getCurrentUserProfile(req.user.id);
    return sendSuccess(res, {
      statusCode: 200,
      message: "User profile fetched successfully",
      data: { user: profile },
    });
  } catch (error) {
    next(error);
  }
};
