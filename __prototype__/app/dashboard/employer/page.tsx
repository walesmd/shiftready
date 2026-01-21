"use client";

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

const stats = [
  {
    name: "Active Shifts",
    value: "12",
    change: "+3 from last week",
    changeType: "positive",
    icon: Calendar,
  },
  {
    name: "Workers Engaged",
    value: "28",
    change: "+5 from last week",
    changeType: "positive",
    icon: Users,
  },
  {
    name: "This Week Spend",
    value: "$4,280",
    change: "Under budget by $720",
    changeType: "positive",
    icon: DollarSign,
  },
  {
    name: "Fill Rate",
    value: "94%",
    change: "+2% from last month",
    changeType: "positive",
    icon: TrendingUp,
  },
];

const upcomingShifts = [
  {
    id: 1,
    role: "Warehouse Packer",
    location: "1200 Commerce St",
    date: "Today",
    time: "2:00 PM - 6:00 PM",
    worker: "Marcus J.",
    status: "confirmed",
    pay: "$68",
  },
  {
    id: 2,
    role: "Moving Assistant",
    location: "845 Industrial Blvd",
    date: "Today",
    time: "4:00 PM - 8:00 PM",
    worker: null,
    status: "recruiting",
    pay: "$80",
  },
  {
    id: 3,
    role: "Lot Driver",
    location: "SA Airport Parking",
    date: "Tomorrow",
    time: "6:00 AM - 12:00 PM",
    worker: "David R.",
    status: "confirmed",
    pay: "$96",
  },
  {
    id: 4,
    role: "Warehouse Packer",
    location: "1200 Commerce St",
    date: "Tomorrow",
    time: "8:00 AM - 12:00 PM",
    worker: "Pending",
    status: "pending",
    pay: "$68",
  },
];

const recentActivity = [
  {
    id: 1,
    message: "Marcus J. accepted shift for Warehouse Packer",
    time: "10 minutes ago",
    type: "success",
  },
  {
    id: 2,
    message: "Recruiting started for Moving Assistant shift",
    time: "25 minutes ago",
    type: "info",
  },
  {
    id: 3,
    message: "Sarah M. completed shift at SA Airport",
    time: "2 hours ago",
    type: "success",
  },
  {
    id: 4,
    message: "Payment processed: $156 for 2 completed shifts",
    time: "3 hours ago",
    type: "info",
  },
];

function getStatusBadge(status: string) {
  switch (status) {
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

export default function EmployerDashboard() {
  return (
    <div className="p-4 lg:p-8 space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Welcome back, Acme Logistics
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
        {stats.map((stat) => (
          <Card key={stat.name}>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div className="w-10 h-10 bg-muted rounded-lg flex items-center justify-center">
                  <stat.icon className="w-5 h-5 text-foreground" />
                </div>
              </div>
              <div className="mt-4">
                <p className="text-2xl font-bold text-foreground">
                  {stat.value}
                </p>
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
            <CardTitle className="text-lg font-semibold">
              Upcoming Shifts
            </CardTitle>
            <Button variant="ghost" size="sm" asChild>
              <Link href="/dashboard/employer/shifts">
                View all
                <ArrowRight className="w-4 h-4 ml-1" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            {upcomingShifts.map((shift) => (
              <div
                key={shift.id}
                className="flex flex-col sm:flex-row sm:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h3 className="font-medium text-foreground">{shift.role}</h3>
                    {getStatusBadge(shift.status)}
                  </div>
                  <div className="flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-4 mt-2 text-sm text-muted-foreground">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5" />
                      {shift.location}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5" />
                      {shift.date}, {shift.time}
                    </span>
                  </div>
                </div>
                <div className="flex items-center justify-between sm:justify-end gap-4">
                  <div className="text-right">
                    <p className="text-sm font-medium text-foreground">
                      {shift.worker || "Finding worker..."}
                    </p>
                    <p className="text-sm text-accent font-semibold">
                      {shift.pay}
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        {/* Recent Activity */}
        <Card>
          <CardHeader className="pb-4">
            <CardTitle className="text-lg font-semibold">
              Recent Activity
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {recentActivity.map((activity) => (
                <div key={activity.id} className="flex gap-3">
                  <div
                    className={`w-2 h-2 rounded-full mt-2 ${
                      activity.type === "success" ? "bg-accent" : "bg-muted-foreground"
                    }`}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-foreground">{activity.message}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {activity.time}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
