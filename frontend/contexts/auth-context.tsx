"use client";

import React, {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  useRef,
} from "react";
import { apiClient, User } from "@/lib/api/client";

export type LoginResult = {
  success: boolean;
  error?: string;
  role?: User["role"];
};

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<LoginResult>;
  register: (
    email: string,
    password: string,
    passwordConfirmation: string,
    role: "worker" | "employer",
    companyAttributes?: Record<string, unknown>,
    employerProfileAttributes?: Record<string, unknown>
  ) => Promise<{ success: boolean; error?: string }>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const hasInitializedRef = useRef(false);

  const refreshUser = useCallback(async () => {
    const token = apiClient.getToken();
    if (!token) {
      setUser(null);
      setIsLoading(false);
      return;
    }

    const response = await apiClient.getCurrentUser();
    if (response.data) {
      setUser(response.data.user);
    } else {
      // Token invalid, clear it
      apiClient.setToken(null);
      setUser(null);
    }
    setIsLoading(false);
  }, []);

  useEffect(() => {
    if (hasInitializedRef.current) {
      return;
    }
    hasInitializedRef.current = true;
    const timeoutId = setTimeout(() => {
      void refreshUser();
    }, 0);
    return () => clearTimeout(timeoutId);
  }, [refreshUser]);

  const login: AuthContextType["login"] = async (email: string, password: string) => {
    const response = await apiClient.login(email, password);
    if (response.data) {
      setUser(response.data.user);
      return { success: true, role: response.data.user.role };
    }
    return { success: false, error: response.error || "Login failed" };
  };

  const register = async (
    email: string,
    password: string,
    passwordConfirmation: string,
    role: "worker" | "employer",
    companyAttributes?: Record<string, unknown>,
    employerProfileAttributes?: Record<string, unknown>
  ) => {
    const response = await apiClient.register(
      email,
      password,
      passwordConfirmation,
      role,
      companyAttributes,
      employerProfileAttributes
    );
    if (response.data) {
      setUser(response.data.user);
      return { success: true };
    }
    return { success: false, error: response.error || "Registration failed" };
  };

  const logout = async () => {
    await apiClient.logout();
    setUser(null);
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isAuthenticated: !!user,
        login,
        register,
        logout,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
