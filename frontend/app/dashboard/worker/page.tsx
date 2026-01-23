"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Calendar,
  Clock,
  DollarSign,
  Star,
  TrendingUp,
  ArrowRight,
  Loader2,
  Briefcase,
  CheckCircle,
  XCircle,
  LogIn,
  AlertCircle,
  CalendarCheck,
  AlertTriangle,
} from "lucide-react";
import { apiClient, type ShiftAssignment, type WorkerProfile, type Activity } from "@/lib/api/client";
import { useAuth } from "@/contexts/auth-context";

interface DashboardStats {
  upcomingShifts: number;
  completedShifts: number;
  totalEarned: number;
  reliabilityScore: number;
}

function getStatusBadge(status: string) {
  switch (status) {
    case "offered":
      return (
        <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">Offer</Badge>
      );
    case "accepted":
    case "confirmed":
      return (
        <Badge className="bg-green-100 text-green-700 hover:bg-green-100">
          Confirmed
        </Badge>
      );
    case "checked_in":
      return (
        <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
          In progress
        </Badge>
      );
    case "completed":
      return (
        <Badge className="bg-emerald-100 text-emerald-700 hover:bg-emerald-100">
          Completed
        </Badge>
      );
    case "declined":
    case "cancelled":
      return (
        <Badge className="bg-rose-100 text-rose-700 hover:bg-rose-100">
          {status === "declined" ? "Declined" : "Cancelled"}
        </Badge>
      );
    case "no_show":
      return (
        <Badge className="bg-destructive/10 text-destructive hover:bg-destructive/10">
          No show
        </Badge>
      );
    default:
      return <Badge variant="secondary">{status}</Badge>;
  }
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const dateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const tomorrowOnly = new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate());

  if (dateOnly.getTime() === todayOnly.getTime()) {
    return "Today";
  } else if (dateOnly.getTime() === tomorrowOnly.getTime()) {
    return "Tomorrow";
  } else {
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  }
}

function formatTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

function getActivityIcon(iconName: string) {
  const iconProps = { className: "w-4 h-4" };
  switch (iconName) {
    case "briefcase":
      return <Briefcase {...iconProps} />;
    case "check-circle":
      return <CheckCircle {...iconProps} />;
    case "x-circle":
      return <XCircle {...iconProps} />;
    case "log-in":
      return <LogIn {...iconProps} />;
    case "alert-circle":
      return <AlertCircle {...iconProps} />;
    case "calendar-check":
      return <CalendarCheck {...iconProps} />;
    case "dollar-sign":
      return <DollarSign {...iconProps} />;
    case "clock":
      return <Clock {...iconProps} />;
    case "loader":
      return <Loader2 {...iconProps} />;
    case "alert-triangle":
      return <AlertTriangle {...iconProps} />;
    default:
      return <Calendar {...iconProps} />;
  }
}

function getActivityStatusColor(status: string) {
  switch (status) {
    case "success":
      return "bg-green-100 text-green-700";
    case "error":
      return "bg-red-100 text-red-700";
    case "pending":
      return "bg-amber-100 text-amber-700";
    case "info":
      return "bg-blue-100 text-blue-700";
    default:
      return "bg-gray-100 text-gray-700";
  }
}

function formatRelativeTime(timestamp: string): string {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export default function WorkerDashboard() {
  const { user } = useAuth();
  const [profile, setProfile] = useState<WorkerProfile | null>(null);
  const [assignments, setAssignments] = useState<ShiftAssignment[]>([]);
  const [activities, setActivities] = useState<Activity[]>([]);
  const [stats, setStats] = useState<DashboardStats>({
    upcomingShifts: 0,
    completedShifts: 0,
    totalEarned: 0,
    reliabilityScore: 0,
  });
  const [loading, setLoading] = useState(true);
  const hasFetchedRef = useRef(false);

  useEffect(() => {
    if (hasFetchedRef.current) {
      return;
    }
    hasFetchedRef.current = true;

    async function fetchData() {
      try {
        const [profileResponse, assignmentsResponse, activitiesResponse] = await Promise.all([
          apiClient.getWorkerProfile(),
          apiClient.getShiftAssignments(),
          apiClient.getActivities(10),
        ]);

        if (profileResponse.data) {
          setProfile(profileResponse.data);
        }

        if (activitiesResponse.data) {
          setActivities(activitiesResponse.data.activities);
        }

        if (assignmentsResponse.data) {
          setAssignments(assignmentsResponse.data.shift_assignments);

          const now = new Date();
          const upcoming = assignmentsResponse.data.shift_assignments.filter((assignment) => {
            const start = new Date(assignment.shift.start_datetime);
            return (
              start >= now &&
              ["offered", "accepted", "confirmed", "checked_in"].includes(assignment.status)
            );
          });

          const completed = assignmentsResponse.data.shift_assignments.filter(
            (assignment) => assignment.status === "completed"
          );

          const totalEarned = completed.reduce(
            (sum, assignment) => sum + (assignment.timesheet?.calculated_pay_cents || 0),
            0
          );

          setStats({
            upcomingShifts: upcoming.length,
            completedShifts: completed.length,
            totalEarned,
            reliabilityScore: Math.round(profileResponse.data?.performance.reliability_score || 0),
          });
        }
      } catch (error) {
        console.error("Failed to fetch worker dashboard data:", error);
      } finally {
        setLoading(false);
      }
    }

    fetchData();
  }, []);

  if (loading) {
    return (
      <div className="p-4 lg:p-8 flex items-center justify-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  const statsData = [
    {
      name: "Upcoming Shifts",
      value: stats.upcomingShifts.toString(),
      change: "Scheduled",
      icon: Calendar,
    },
    {
      name: "Completed Shifts",
      value: stats.completedShifts.toString(),
      change: "All time",
      icon: TrendingUp,
    },
    {
      name: "Total Earned",
      value: `$${(stats.totalEarned / 100).toLocaleString()}`,
      change: "Completed payouts",
      icon: DollarSign,
    },
    {
      name: "Reliability Score",
      value: `${stats.reliabilityScore}%`,
      change: "Based on attendance",
      icon: Star,
    },
  ];

  const upcomingAssignments = assignments
    .filter((assignment) => {
      const start = new Date(assignment.shift.start_datetime);
      return (
        start >= new Date() &&
        ["offered", "accepted", "confirmed", "checked_in"].includes(assignment.status)
      );
    })
    .sort(
      (a, b) =>
        new Date(a.shift.start_datetime).getTime() -
        new Date(b.shift.start_datetime).getTime()
    )
    .slice(0, 4);

  return (
    <div className="p-4 lg:p-8 space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Welcome back, {profile?.first_name || user?.email || "Worker"}
          </h1>
          <p className="text-muted-foreground mt-1">
            Here is what is happening with your shifts today.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/worker/shifts">
            <Calendar className="w-4 h-4 mr-2" />
            Browse Shifts
          </Link>
        </Button>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {statsData.map((stat) => (
          <Card key={stat.name}>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-muted rounded-lg flex items-center justify-center">
                  <stat.icon className="w-5 h-5 text-foreground" />
                </div>
              </div>
              <div className="mt-4">
                <p className="text-2xl font-bold text-foreground">{stat.value}</p>
                <p className="text-sm text-muted-foreground">{stat.name}</p>
              </div>
              <p className="text-xs text-accent mt-2">{stat.change}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Upcoming Shifts */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <CardTitle className="text-lg font-semibold">Upcoming Shifts</CardTitle>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/dashboard/worker/shifts">
                View all
                <ArrowRight className="w-4 h-4 ml-1" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            {upcomingAssignments.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No upcoming shifts</p>
                <p className="text-sm mt-1">Check back soon for new offers</p>
              </div>
            ) : (
              upcomingAssignments.map((assignment) => (
                <div
                  key={assignment.id}
                  className="flex flex-col sm:flex-row sm:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-medium text-foreground">
                        {assignment.shift.title}
                      </h3>
                      {getStatusBadge(assignment.status)}
                    </div>
                    <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-4 mt-2 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {formatDate(assignment.shift.start_datetime)},{" "}
                        {formatTime(assignment.shift.start_datetime)} -{" "}
                        {formatTime(assignment.shift.end_datetime)}
                      </span>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-foreground">
                      {assignment.shift.formatted_pay_rate}
                    </p>
                  </div>
                </div>
              ))
            )}
          </CardContent>
        </Card>

        {/* Recent Activity */}
        <Card>
          <CardHeader className="pb-4">
            <CardTitle className="text-lg font-semibold">Recent Activity</CardTitle>
          </CardHeader>
          <CardContent>
            {activities.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Clock className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No recent activity</p>
                <p className="text-sm mt-1">Your activity will appear here</p>
              </div>
            ) : (
              <div className="space-y-3">
                {activities.slice(0, 8).map((activity) => (
                  <div
                    key={activity.id}
                    className="flex items-start gap-3 p-2 rounded-lg hover:bg-muted/50 transition-colors"
                  >
                    <div
                      className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${getActivityStatusColor(
                        activity.status
                      )}`}
                    >
                      {getActivityIcon(activity.icon)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-foreground truncate">
                        {activity.title}
                      </p>
                      <p className="text-xs text-muted-foreground truncate">
                        {activity.description}
                      </p>
                    </div>
                    <span className="text-xs text-muted-foreground whitespace-nowrap">
                      {formatRelativeTime(activity.timestamp)}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
