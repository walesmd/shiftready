"use client";

import { useEffect, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { CheckCircle2, Circle, Loader2, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useOnboarding } from "@/contexts/onboarding-context";
import type { OnboardingStatus } from "@/lib/api/client";

interface OnboardingTask {
  id: string;
  title: string;
  description: string;
  completed: boolean;
  actionLink: string;
  actionLabel: string;
}

export function OnboardingCard() {
  const router = useRouter();
  const { onboardingStatus, isLoading, refreshOnboardingStatus } = useOnboarding();
  const [isDismissed, setIsDismissed] = useState(false);

  useEffect(() => {
    // Load onboarding status on mount
    refreshOnboardingStatus();
  }, [refreshOnboardingStatus]);

  useEffect(() => {
    // Auto-dismiss if onboarding is complete
    if (onboardingStatus?.all_tasks_complete) {
      setIsDismissed(true);
    }
  }, [onboardingStatus]);

  if (isLoading) {
    return (
      <Card className="mb-6 border-amber-200 bg-amber-50">
        <CardContent className="flex items-center justify-center py-8">
          <Loader2 className="h-6 w-6 animate-spin text-amber-600" />
        </CardContent>
      </Card>
    );
  }

  // Don't show if dismissed or onboarding is complete
  if (isDismissed || !onboardingStatus || onboardingStatus.all_tasks_complete) {
    return null;
  }

  const tasks: OnboardingTask[] = [
    {
      id: "billing_info",
      title: "Add billing information",
      description: "Complete your company's billing address, email, and phone number",
      completed: onboardingStatus.tasks.billing_info_complete,
      actionLink: "/dashboard/employer/settings?tab=company",
      actionLabel: "Add Billing Info",
    },
    {
      id: "work_location",
      title: "Add a work location",
      description: "Add at least one work location where shifts will take place",
      completed: onboardingStatus.tasks.work_locations_added,
      actionLink: "/dashboard/employer/settings?tab=company",
      actionLabel: "Add Location",
    },
  ];

  const completedCount = tasks.filter((task) => task.completed).length;
  const totalCount = tasks.length;

  return (
    <Card className="mb-6 border-amber-200 bg-amber-50">
      <CardHeader className="relative pb-3">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2">
              <CardTitle className="text-lg">Complete Your Account Setup</CardTitle>
              <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
                {completedCount} of {totalCount}
              </Badge>
            </div>
            <CardDescription className="mt-1">
              Finish these steps to activate your account and start posting shifts
            </CardDescription>
          </div>
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-amber-600 hover:bg-amber-100 hover:text-amber-700"
            onClick={() => setIsDismissed(true)}
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3 pb-4">
        {tasks.map((task) => (
          <div
            key={task.id}
            className="flex items-start gap-3 rounded-lg bg-white p-3 shadow-sm"
          >
            <div className="mt-0.5">
              {task.completed ? (
                <CheckCircle2 className="h-5 w-5 text-emerald-600" />
              ) : (
                <Circle className="h-5 w-5 text-gray-400" />
              )}
            </div>
            <div className="flex-1 min-w-0">
              <h4 className="font-medium text-sm text-gray-900">{task.title}</h4>
              <p className="text-xs text-gray-600 mt-0.5">{task.description}</p>
            </div>
            {!task.completed && (
              <Button
                size="sm"
                variant="outline"
                className="ml-2 shrink-0 border-amber-300 text-amber-700 hover:bg-amber-100 hover:text-amber-800"
                onClick={() => router.push(task.actionLink)}
              >
                {task.actionLabel}
              </Button>
            )}
          </div>
        ))}
      </CardContent>
    </Card>
  );
}
