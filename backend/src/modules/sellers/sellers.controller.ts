import type { Response, NextFunction } from "express";
import type { AuthenticatedRequest } from "../../middleware/auth.middleware.ts";
import {
  registerSeller,
  getSellerStatusByUserId,
  resubmitSellerApplication,
  forgotPassword,
  getSellerDashboardStats,
  createSellerProduct,
  getSellerProducts,
  getSellerProductById,
  updateSellerProduct,
  deleteSellerProduct,
  updateSellerProductStock,
  toggleSellerProductStatus,
} from "./sellers.service.ts";
import {
  validateSellerRegistration,
  validateCreateProduct,
} from "./sellers.validation.ts";
import { sendSuccess } from "../../utils/apiResponse.ts";
import { AppError } from "../../middleware/errorHandler.ts";

export const register = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const validatedInput = validateSellerRegistration(req.body);
    const result = await registerSeller(validatedInput);

    sendSuccess(res, {
      statusCode: 201,
      message: result.message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getStatus = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await getSellerStatusByUserId(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller application status retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const resubmit = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await resubmitSellerApplication(req.user.id, req.body);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller application resubmitted successfully. It is now under review.",
      data: { store: result },
    });
  } catch (error) {
    next(error);
  }
};

export const requestPasswordReset = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { email } = req.body;
    const result = await forgotPassword(email);

    sendSuccess(res, {
      statusCode: 200,
      message: result.message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getDashboard = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await getSellerDashboardStats(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller dashboard metrics retrieved",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const createProduct = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const validatedInput = validateCreateProduct(req.body);
    const result = await createSellerProduct(req.user.id, validatedInput);

    sendSuccess(res, {
      statusCode: 201,
      message: "Product created successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getProducts = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const result = await getSellerProducts(req.user.id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Seller products retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const getProductById = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    const result = await getSellerProductById(req.user.id, id);

    sendSuccess(res, {
      statusCode: 200,
      message: "Product retrieved successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const updateProduct = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    const result = await updateSellerProduct(req.user.id, id, req.body);

    sendSuccess(res, {
      statusCode: 200,
      message: "Product updated successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const deleteProduct = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    const result = await deleteSellerProduct(req.user.id, id);

    sendSuccess(res, {
      statusCode: 200,
      message: result.message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const updateStock = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    const { stock } = req.body;
    const result = await updateSellerProductStock(req.user.id, id, Number(stock));

    sendSuccess(res, {
      statusCode: 200,
      message: "Stock updated successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

export const toggleStatus = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    if (!req.user) {
      return next(new AppError("Authentication required", 401));
    }

    const { id } = req.params;
    const { status } = req.body;
    const result = await toggleSellerProductStatus(req.user.id, id, status);

    sendSuccess(res, {
      statusCode: 200,
      message: "Product status updated successfully",
      data: result,
    });
  } catch (error) {
    next(error);
  }
};
