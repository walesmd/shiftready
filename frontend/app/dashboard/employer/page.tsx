"use client";

import { useEffect, useRef, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Calendar,
  Users,
  DollarSign,
  TrendingUp,
  ArrowRight,
  Clock,
  MapPin,
  CheckCircle2,
  AlertCircle,
  Loader2,
} from "lucide-react";
import Link from "next/link";
import { apiClient, type Shift, type EmployerProfile } from "@/lib/api/client";
import { useAuth } from "@/contexts/auth-context";

interface DashboardStats {
  activeShifts: number;
  workersEngaged: number;
  weekSpend: number;
  fillRate: number;
}

function getStatusBadge(status: string) {
  switch (status) {
    case "filled":
    case "confirmed":
      return (
        <Badge className="bg-green-100 text-green-700 hover:bg-green-100">
          <CheckCircle2 className="w-3 h-3 mr-1" />
          Confirmed
        </Badge>
      );
    case "recruiting":
      return (
        <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
          <Loader2 className="w-3 h-3 mr-1 animate-spin" />
          Recruiting
        </Badge>
      );
    case "posted":
    case "pending":
      return (
        <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">
          <AlertCircle className="w-3 h-3 mr-1" />
          Pending
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

export default function EmployerDashboard() {
  const { user } = useAuth();
  const [profile, setProfile] = useState<EmployerProfile | null>(null);
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [stats, setStats] = useState<DashboardStats>({
    activeShifts: 0,
    workersEngaged: 0,
    weekSpend: 0,
    fillRate: 0,
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
        // Fetch employer profile
        const profileResponse = await apiClient.getEmployerProfile();
        if (profileResponse.data) {
          setProfile(profileResponse.data);
        }

        // Fetch upcoming shifts (posted, recruiting, filled, in_progress)
        const shiftsResponse = await apiClient.getShifts({
          status: "posted,recruiting,filled,in_progress",
        });

        if (shiftsResponse.data) {
          const upcomingShifts = shiftsResponse.data.shifts
            .filter((shift) => new Date(shift.schedule.start_datetime) >= new Date())
            .sort(
              (a, b) =>
                new Date(a.schedule.start_datetime).getTime() -
                new Date(b.schedule.start_datetime).getTime()
            )
            .slice(0, 4);

          setShifts(upcomingShifts);

          // Calculate stats
          const activeShiftsCount = shiftsResponse.data.shifts.filter(
            (s) => ["posted", "recruiting", "filled", "in_progress"].includes(s.status)
          ).length;

          const workersCount = shiftsResponse.data.shifts.reduce(
            (sum, s) => sum + s.capacity.slots_filled,
            0
          );

          const weekSpend = shiftsResponse.data.shifts
            .filter((s) => {
              const shiftDate = new Date(s.schedule.start_datetime);
              const weekAgo = new Date();
              weekAgo.setDate(weekAgo.getDate() - 7);
              return shiftDate >= weekAgo && s.status === "completed";
            })
            .reduce((sum, s) => sum + s.pay.estimated_total, 0);

          const fillableShifts = shiftsResponse.data.shifts.filter(
            (s) => s.capacity.slots_total > 0
          );
          const fillRate =
            fillableShifts.length > 0
              ? (fillableShifts.reduce(
                  (sum, s) => sum + (s.capacity.slots_filled / s.capacity.slots_total),
                  0
                ) /
                  fillableShifts.length) *
                100
              : 0;

          setStats({
            activeShifts: activeShiftsCount,
            workersEngaged: workersCount,
            weekSpend,
            fillRate: Math.round(fillRate),
          });
        }
      } catch (error) {
        console.error("Failed to fetch dashboard data:", error);
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
      name: "Active Shifts",
      value: stats.activeShifts.toString(),
      change: `${shifts.length} upcoming`,
      changeType: "positive",
      icon: Calendar,
    },
    {
      name: "Workers Engaged",
      value: stats.workersEngaged.toString(),
      change: "Across all shifts",
      changeType: "positive",
      icon: Users,
    },
    {
      name: "This Week Spend",
      value: `$${stats.weekSpend.toLocaleString()}`,
      change: "Last 7 days",
      changeType: "positive",
      icon: DollarSign,
    },
    {
      name: "Fill Rate",
      value: `${stats.fillRate}%`,
      change: "Average across shifts",
      changeType: "positive",
      icon: TrendingUp,
    },
  ];

  return (
    <div className="p-4 lg:p-8 space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Welcome back, {profile?.company?.name || "Employer"}
          </h1>
          <p className="text-muted-foreground mt-1">
            Here is what is happening with your shifts today.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/employer/shifts">
            <Calendar className="w-4 h-4 mr-2" />
            Post New Shift
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
              <Link href="/dashboard/employer/shifts">
                View all
                <ArrowRight className="w-4 h-4 ml-1" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            {shifts.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No upcoming shifts</p>
                <p className="text-sm mt-1">Post a new shift to get started</p>
              </div>
            ) : (
              shifts.map((shift) => (
                <div
                  key={shift.id}
                  className="flex flex-col sm:flex-row sm:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-medium text-foreground">{shift.title}</h3>
                      {getStatusBadge(shift.status)}
                    </div>
                    <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-4 mt-2 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3.5 h-3.5" />
                        {shift.work_location.name}
                      </span>
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {formatDate(shift.schedule.start_datetime)},{" "}
                        {formatTime(shift.schedule.start_datetime)} -{" "}
                        {formatTime(shift.schedule.end_datetime)}
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between sm:justify-end gap-4">
                    <div className="text-right">
                      <p className="text-sm font-medium text-foreground">
                        {shift.capacity.slots_filled > 0
                          ? `${shift.capacity.slots_filled}/${shift.capacity.slots_total} filled`
                          : "Finding worker..."}
                      </p>
                      <p className="text-sm text-accent font-semibold">
                        {shift.pay.formatted_estimated}
                      </p>
                    </div>
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
            <div className="text-center py-8 text-muted-foreground">
              <p className="text-sm">Activity feed coming soon</p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
