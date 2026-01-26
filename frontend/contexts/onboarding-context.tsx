"use client";

import { createContext, useContext, useState, useCallback, ReactNode } from "react";
import { apiClient, type OnboardingStatus } from "@/lib/api/client";

interface OnboardingContextType {
  onboardingStatus: OnboardingStatus | null;
  isLoading: boolean;
  refreshOnboardingStatus: () => Promise<void>;
}

const OnboardingContext = createContext<OnboardingContextType | undefined>(undefined);

interface OnboardingProviderProps {
  children: ReactNode;
  userRole: "employer" | "worker";
}

export function OnboardingProvider({ children, userRole }: OnboardingProviderProps) {
  const [onboardingStatus, setOnboardingStatus] = useState<OnboardingStatus | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const refreshOnboardingStatus = useCallback(async () => {
    setIsLoading(true);
    try {
      // Fetch based on user role
      let response;
      if (userRole === "employer") {
        response = await apiClient.getEmployerOnboardingStatus();
      } else {
        // Worker onboarding - to be implemented later
        // response = await apiClient.getWorkerOnboardingStatus();
        return;
      }

      if (response.data && !response.error) {
        setOnboardingStatus(response.data);
      }
    } catch (error) {
      console.error("Failed to fetch onboarding status:", error);
    } finally {
      setIsLoading(false);
    }
  }, [userRole]);

  return (
    <OnboardingContext.Provider
      value={{
        onboardingStatus,
        isLoading,
        refreshOnboardingStatus,
      }}
    >
      {children}
    </OnboardingContext.Provider>
  );
}

export function useOnboarding() {
  const context = useContext(OnboardingContext);
  if (context === undefined) {
    throw new Error("useOnboarding must be used within an OnboardingProvider");
  }
  return context;
}
