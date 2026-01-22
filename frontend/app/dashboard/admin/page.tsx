"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Calendar,
  Users,
  Briefcase,
  TrendingUp,
  ArrowRight,
  Clock,
  MapPin,
  User,
  Loader2,
} from "lucide-react";
import { apiClient, type Shift, type ShiftAssignment } from "@/lib/api/client";
import { useAuth } from "@/contexts/auth-context";

interface DashboardStats {
  totalShifts: number;
  workersScheduled: number;
  openSlots: number;
  fillRate: number;
}

function getShiftStatusBadge(status: string) {
  switch (status) {
    case "filled":
    case "confirmed":
      return (
        <Badge className="bg-green-100 text-green-700 hover:bg-green-100">Confirmed</Badge>
      );
    case "recruiting":
      return (
        <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
          Recruiting
        </Badge>
      );
    case "posted":
    case "pending":
      return (
        <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">Pending</Badge>
      );
    case "in_progress":
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
    case "cancelled":
      return (
        <Badge className="bg-rose-100 text-rose-700 hover:bg-rose-100">Cancelled</Badge>
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

function isSameDay(date: Date, comparison: Date) {
  return (
    date.getFullYear() === comparison.getFullYear() &&
    date.getMonth() === comparison.getMonth() &&
    date.getDate() === comparison.getDate()
  );
}

function formatWorkerSummary(assignments: ShiftAssignment[]) {
  const activeAssignments = assignments.filter((assignment) =>
    ["accepted", "confirmed", "checked_in", "completed"].includes(assignment.status)
  );
  const uniqueWorkers = new Map<number, string>();
  activeAssignments.forEach((assignment) => {
    uniqueWorkers.set(assignment.worker.id, assignment.worker.full_name);
  });
  const workerNames = Array.from(uniqueWorkers.values());

  if (workerNames.length === 0) {
    return "Unassigned";
  }

  const displayed = workerNames.slice(0, 2);
  const remaining = workerNames.length - displayed.length;
  return remaining > 0 ? `${displayed.join(", ")} +${remaining} more` : displayed.join(", ");
}

export default function AdminDashboard() {
  const { user } = useAuth();
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [assignments, setAssignments] = useState<ShiftAssignment[]>([]);
  const [stats, setStats] = useState<DashboardStats>({
    totalShifts: 0,
    workersScheduled: 0,
    openSlots: 0,
    fillRate: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const hasFetchedRef = useRef(false);

  const fetchData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date();
      endOfDay.setHours(23, 59, 59, 999);

      const shiftsResponse = await apiClient.getShifts({
        start_date: startOfDay.toISOString(),
        end_date: endOfDay.toISOString(),
      });

      const shiftItems =
        shiftsResponse.data?.shifts ??
        (shiftsResponse.data as { items?: { id: number }[] } | null)?.items ??
        [];
      const shiftIds = shiftItems.map((shift) => shift.id);
      const assignmentsResponse =
        shiftIds.length > 0
          ? await apiClient.getShiftAssignments({ shift_ids: shiftIds })
          : {
              data: { shift_assignments: [], meta: { total: 0 } },
              error: null,
              status: 200,
            };

      const today = new Date();
      const todayShifts =
        (shiftsResponse.data?.shifts ?? shiftItems).filter((shift: Shift) =>
          isSameDay(new Date(shift.schedule.start_datetime), today)
        ) || [];

      setShifts(todayShifts);
      setAssignments(assignmentsResponse.data?.shift_assignments || []);

      const totalSlots = todayShifts.reduce(
        (sum, shift) => sum + shift.capacity.slots_total,
        0
      );
      const filledSlots = todayShifts.reduce(
        (sum, shift) => sum + shift.capacity.slots_filled,
        0
      );
      const openSlots = todayShifts.reduce(
        (sum, shift) => sum + shift.capacity.slots_available,
        0
      );

      setStats({
        totalShifts: todayShifts.length,
        workersScheduled: filledSlots,
        openSlots,
        fillRate: totalSlots > 0 ? Math.round((filledSlots / totalSlots) * 100) : 0,
      });
    } catch (error) {
      console.error("Failed to fetch admin dashboard data:", error);
      if (error instanceof Error) {
        setError(error.message || "Failed to load dashboard");
      } else {
        setError("Failed to load dashboard");
      }
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (hasFetchedRef.current) {
      return;
    }
    hasFetchedRef.current = true;
    fetchData();
  }, [fetchData]);

  const assignmentsByShift = useMemo(() => {
    const map = new Map<number, ShiftAssignment[]>();
    assignments.forEach((assignment) => {
      const list = map.get(assignment.shift.id) || [];
      list.push(assignment);
      map.set(assignment.shift.id, list);
    });
    return map;
  }, [assignments]);

  const sortedShifts = [...shifts].sort(
    (a, b) =>
      new Date(a.schedule.start_datetime).getTime() -
      new Date(b.schedule.start_datetime).getTime()
  );

  if (loading) {
    return (
      <div className="p-4 lg:p-8 flex items-center justify-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 lg:p-8 flex flex-col items-center justify-center min-h-[400px] text-center gap-4">
        <p className="text-sm text-muted-foreground">{error}</p>
        <Button onClick={fetchData}>Retry</Button>
      </div>
    );
  }

  const statsData = [
    {
      name: "Shifts Today",
      value: stats.totalShifts.toString(),
      change: "Across all companies",
      icon: Calendar,
    },
    {
      name: "Workers Scheduled",
      value: stats.workersScheduled.toString(),
      change: "Assigned workers",
      icon: Users,
    },
    {
      name: "Open Slots",
      value: stats.openSlots.toString(),
      change: "Remaining capacity",
      icon: Briefcase,
    },
    {
      name: "Fill Rate",
      value: `${stats.fillRate}%`,
      change: "Today average",
      icon: TrendingUp,
    },
  ];

  return (
    <div className="p-4 lg:p-8 space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Admin overview{user?.email ? `, ${user.email}` : ""}
          </h1>
          <p className="text-muted-foreground mt-1">
            Today&apos;s shifts and platform-wide KPIs.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/admin/shifts">
            <Calendar className="w-4 h-4 mr-2" />
            View all shifts
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
        {/* Today's Shifts */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <CardTitle className="text-lg font-semibold">Shifts happening today</CardTitle>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/dashboard/admin/shifts">
                View all
                <ArrowRight className="w-4 h-4 ml-1" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            {sortedShifts.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No shifts scheduled today</p>
                <p className="text-sm mt-1">You will see shifts here as they are posted</p>
              </div>
            ) : (
              sortedShifts.map((shift) => {
                const shiftAssignments = assignmentsByShift.get(shift.id) || [];
                return (
                  <div
                    key={shift.id}
                    className="flex flex-col sm:flex-row sm:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-medium text-foreground">{shift.title}</h3>
                        {getShiftStatusBadge(shift.status)}
                      </div>
                      <p className="text-sm text-muted-foreground mt-1">
                        {shift.company.name}
                      </p>
                      <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-4 mt-2 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5" />
                          {shift.work_location.name},{" "}
                          {shift.work_location.city}, {shift.work_location.state}
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="w-3.5 h-3.5" />
                          {formatDate(shift.schedule.start_datetime)},{" "}
                          {formatTime(shift.schedule.start_datetime)} -{" "}
                          {formatTime(shift.schedule.end_datetime)}
                        </span>
                      </div>
                      <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-4 mt-2 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <User className="w-3.5 h-3.5" />
                          {shift.created_by.name}
                        </span>
                        <span className="flex items-center gap-1">
                          <Users className="w-3.5 h-3.5" />
                          {formatWorkerSummary(shiftAssignments)}
                        </span>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-foreground">
                        {shift.pay.formatted_rate}
                      </p>
                      <p className="text-sm text-accent font-semibold">
                        {shift.capacity.slots_filled}/{shift.capacity.slots_total} filled
                      </p>
                    </div>
                  </div>
                );
              })
            )}
          </CardContent>
        </Card>

        {/* Admin Access */}
        <Card>
          <CardHeader className="pb-4">
            <CardTitle className="text-lg font-semibold">Admin access</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm text-muted-foreground">
            <p>
              You can view and manage all shifts, companies, employers, and workers without
              restrictions.
            </p>
            <p>
              Use this dashboard to monitor today&apos;s operations and take action on
              behalf of any user when needed.
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
