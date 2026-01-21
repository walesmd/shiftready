"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import {
  Plus,
  Search,
  Filter,
  Calendar,
  MapPin,
  Clock,
  User,
  DollarSign,
  CheckCircle2,
  AlertCircle,
  Loader2,
  XCircle,
  MoreHorizontal,
  Eye,
  Edit,
  Trash2,
} from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useSearchParams } from "next/navigation";
import { Suspense } from "react";

type ShiftStatus = "confirmed" | "recruiting" | "pending" | "open" | "completed" | "cancelled";

interface Shift {
  id: number;
  role: string;
  location: string;
  address: string;
  date: string;
  startTime: string;
  endTime: string;
  worker: string | null;
  workerInitials: string | null;
  pay: number;
  status: ShiftStatus;
  createdAt: string;
}

const shiftsData: Shift[] = [
  {
    id: 1001,
    role: "Warehouse Packer",
    location: "Main Warehouse",
    address: "1200 Commerce St, San Antonio",
    date: "2026-01-20",
    startTime: "2:00 PM",
    endTime: "6:00 PM",
    worker: "Marcus Johnson",
    workerInitials: "MJ",
    pay: 68,
    status: "confirmed",
    createdAt: "2026-01-18",
  },
  {
    id: 1002,
    role: "Moving Assistant",
    location: "Industrial Hub",
    address: "845 Industrial Blvd, San Antonio",
    date: "2026-01-20",
    startTime: "4:00 PM",
    endTime: "8:00 PM",
    worker: null,
    workerInitials: null,
    pay: 80,
    status: "recruiting",
    createdAt: "2026-01-19",
  },
  {
    id: 1003,
    role: "Lot Driver",
    location: "SA Airport Parking",
    address: "9800 Airport Blvd, San Antonio",
    date: "2026-01-21",
    startTime: "6:00 AM",
    endTime: "12:00 PM",
    worker: "David Rodriguez",
    workerInitials: "DR",
    pay: 96,
    status: "confirmed",
    createdAt: "2026-01-17",
  },
  {
    id: 1004,
    role: "Warehouse Packer",
    location: "Main Warehouse",
    address: "1200 Commerce St, San Antonio",
    date: "2026-01-21",
    startTime: "8:00 AM",
    endTime: "12:00 PM",
    worker: null,
    workerInitials: null,
    pay: 68,
    status: "pending",
    createdAt: "2026-01-19",
  },
  {
    id: 1005,
    role: "Event Setup",
    location: "Convention Center",
    address: "900 E Market St, San Antonio",
    date: "2026-01-22",
    startTime: "7:00 AM",
    endTime: "3:00 PM",
    worker: null,
    workerInitials: null,
    pay: 128,
    status: "open",
    createdAt: "2026-01-20",
  },
  {
    id: 1006,
    role: "Furniture Mover",
    location: "Downtown Office",
    address: "300 Convent St, San Antonio",
    date: "2026-01-22",
    startTime: "9:00 AM",
    endTime: "1:00 PM",
    worker: "Carlos Mendez",
    workerInitials: "CM",
    pay: 72,
    status: "confirmed",
    createdAt: "2026-01-18",
  },
  {
    id: 1007,
    role: "Lot Driver",
    location: "SA Airport Parking",
    address: "9800 Airport Blvd, San Antonio",
    date: "2026-01-19",
    startTime: "6:00 AM",
    endTime: "12:00 PM",
    worker: "Sarah Mitchell",
    workerInitials: "SM",
    pay: 96,
    status: "completed",
    createdAt: "2026-01-15",
  },
  {
    id: 1008,
    role: "Warehouse Packer",
    location: "Main Warehouse",
    address: "1200 Commerce St, San Antonio",
    date: "2026-01-19",
    startTime: "2:00 PM",
    endTime: "6:00 PM",
    worker: "James Wilson",
    workerInitials: "JW",
    pay: 68,
    status: "completed",
    createdAt: "2026-01-16",
  },
  {
    id: 1009,
    role: "Moving Assistant",
    location: "Residential",
    address: "4521 Oak Grove, San Antonio",
    date: "2026-01-23",
    startTime: "10:00 AM",
    endTime: "4:00 PM",
    worker: null,
    workerInitials: null,
    pay: 108,
    status: "recruiting",
    createdAt: "2026-01-20",
  },
  {
    id: 1010,
    role: "Box Packer",
    location: "Distribution Center",
    address: "5600 Logistics Way, San Antonio",
    date: "2026-01-18",
    startTime: "8:00 AM",
    endTime: "4:00 PM",
    worker: null,
    workerInitials: null,
    pay: 136,
    status: "cancelled",
    createdAt: "2026-01-14",
  },
];

function getStatusConfig(status: ShiftStatus) {
  switch (status) {
    case "confirmed":
      return {
        label: "Confirmed",
        icon: CheckCircle2,
        className: "bg-green-100 text-green-700 hover:bg-green-100",
      };
    case "recruiting":
      return {
        label: "Recruiting",
        icon: Loader2,
        className: "bg-amber-100 text-amber-700 hover:bg-amber-100",
        animate: true,
      };
    case "pending":
      return {
        label: "Pending",
        icon: AlertCircle,
        className: "bg-blue-100 text-blue-700 hover:bg-blue-100",
      };
    case "open":
      return {
        label: "Open",
        icon: Clock,
        className: "bg-gray-100 text-gray-700 hover:bg-gray-100",
      };
    case "completed":
      return {
        label: "Completed",
        icon: CheckCircle2,
        className: "bg-emerald-100 text-emerald-700 hover:bg-emerald-100",
      };
    case "cancelled":
      return {
        label: "Cancelled",
        icon: XCircle,
        className: "bg-red-100 text-red-700 hover:bg-red-100",
      };
    default:
      return {
        label: status,
        icon: AlertCircle,
        className: "bg-gray-100 text-gray-700",
      };
  }
}

function StatusBadge({ status }: { status: ShiftStatus }) {
  const config = getStatusConfig(status);
  const Icon = config.icon;

  return (
    <Badge className={config.className}>
      <Icon
        className={`w-3 h-3 mr-1 ${
          "animate" in config && config.animate ? "animate-spin" : ""
        }`}
      />
      {config.label}
    </Badge>
  );
}

function formatDate(dateString: string) {
  const date = new Date(dateString);
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  if (date.toDateString() === today.toDateString()) {
    return "Today";
  } else if (date.toDateString() === tomorrow.toDateString()) {
    return "Tomorrow";
  } else {
    return date.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
    });
  }
}

const Loading = () => null;

export default function ShiftsPage() {
  const searchParams = useSearchParams();
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [isDialogOpen, setIsDialogOpen] = useState(false);

  const filteredShifts = shiftsData.filter((shift) => {
    const matchesSearch =
      shift.role.toLowerCase().includes(searchQuery.toLowerCase()) ||
      shift.location.toLowerCase().includes(searchQuery.toLowerCase()) ||
      shift.worker?.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStatus =
      statusFilter === "all" || shift.status === statusFilter;

    const matchesRole = roleFilter === "all" || shift.role === roleFilter;

    return matchesSearch && matchesStatus && matchesRole;
  });

  const roles = [...new Set(shiftsData.map((s) => s.role))];

  const statusCounts = {
    all: shiftsData.length,
    open: shiftsData.filter((s) => s.status === "open").length,
    recruiting: shiftsData.filter((s) => s.status === "recruiting").length,
    pending: shiftsData.filter((s) => s.status === "pending").length,
    confirmed: shiftsData.filter((s) => s.status === "confirmed").length,
    completed: shiftsData.filter((s) => s.status === "completed").length,
    cancelled: shiftsData.filter((s) => s.status === "cancelled").length,
  };

  return (
    <Suspense fallback={<Loading />}>
      <div className="p-4 lg:p-8 space-y-6">
        {/* Page Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-foreground">Shifts</h1>
            <p className="text-muted-foreground mt-1">
              Manage and track all your staffing shifts
            </p>
          </div>
          <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <Plus className="w-4 h-4 mr-2" />
                Post New Shift
              </Button>
            </DialogTrigger>
            <DialogContent className="sm:max-w-lg">
              <DialogHeader>
                <DialogTitle>Post a New Shift</DialogTitle>
                <DialogDescription>
                  Create a new shift and we will start recruiting workers for you.
                </DialogDescription>
              </DialogHeader>
              <div className="grid gap-4 py-4">
                <div className="grid gap-2">
                  <Label htmlFor="role">Role</Label>
                  <Select>
                    <SelectTrigger id="role">
                      <SelectValue placeholder="Select a role" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="warehouse-packer">Warehouse Packer</SelectItem>
                      <SelectItem value="moving-assistant">Moving Assistant</SelectItem>
                      <SelectItem value="lot-driver">Lot Driver</SelectItem>
                      <SelectItem value="event-setup">Event Setup</SelectItem>
                      <SelectItem value="furniture-mover">Furniture Mover</SelectItem>
                      <SelectItem value="box-packer">Box Packer</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="location">Location</Label>
                  <Select>
                    <SelectTrigger id="location">
                      <SelectValue placeholder="Select a location" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="main-warehouse">Main Warehouse - 1200 Commerce St</SelectItem>
                      <SelectItem value="airport">SA Airport Parking - 9800 Airport Blvd</SelectItem>
                      <SelectItem value="industrial">Industrial Hub - 845 Industrial Blvd</SelectItem>
                      <SelectItem value="convention">Convention Center - 900 E Market St</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="grid gap-2">
                    <Label htmlFor="date">Date</Label>
                    <Input id="date" type="date" />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="workers">Workers Needed</Label>
                    <Input id="workers" type="number" min="1" defaultValue="1" />
                  </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div className="grid gap-2">
                    <Label htmlFor="start-time">Start Time</Label>
                    <Input id="start-time" type="time" />
                  </div>
                  <div className="grid gap-2">
                    <Label htmlFor="end-time">End Time</Label>
                    <Input id="end-time" type="time" />
                  </div>
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="pay">Pay Rate ($/hour)</Label>
                  <Input id="pay" type="number" min="15" step="0.5" defaultValue="17" />
                </div>
              </div>
              <div className="flex justify-end gap-3">
                <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
                  Cancel
                </Button>
                <Button onClick={() => setIsDialogOpen(false)}>
                  Post Shift
                </Button>
              </div>
            </DialogContent>
          </Dialog>
        </div>

        {/* Status Tabs */}
        <div className="flex flex-wrap gap-2">
          {[
            { key: "all", label: "All" },
            { key: "open", label: "Open" },
            { key: "recruiting", label: "Recruiting" },
            { key: "pending", label: "Pending" },
            { key: "confirmed", label: "Confirmed" },
            { key: "completed", label: "Completed" },
          ].map((tab) => (
            <Button
              key={tab.key}
              variant={statusFilter === tab.key ? "default" : "outline"}
              size="sm"
              onClick={() => setStatusFilter(tab.key)}
              className="gap-2"
            >
              {tab.label}
              <span
                className={`text-xs px-1.5 py-0.5 rounded-full ${
                  statusFilter === tab.key
                    ? "bg-background/20 text-background"
                    : "bg-muted text-muted-foreground"
                }`}
              >
                {statusCounts[tab.key as keyof typeof statusCounts]}
              </span>
            </Button>
          ))}
        </div>

        {/* Filters */}
        <Card>
          <CardContent className="p-4">
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input
                  placeholder="Search by role, location, or worker..."
                  className="pl-9"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
              <div className="flex gap-2">
                <Select value={roleFilter} onValueChange={setRoleFilter}>
                  <SelectTrigger className="w-[180px]">
                    <Filter className="w-4 h-4 mr-2" />
                    <SelectValue placeholder="Filter by role" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Roles</SelectItem>
                    {roles.map((role) => (
                      <SelectItem key={role} value={role}>
                        {role}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Shifts Table */}
        <Card>
          <CardHeader className="pb-0">
            <CardTitle className="text-base font-medium">
              {filteredShifts.length} shift{filteredShifts.length !== 1 ? "s" : ""}{" "}
              {statusFilter !== "all" && `(${statusFilter})`}
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[100px]">
                      <div className="flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5" />
                        Date
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        Time
                      </div>
                    </TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <MapPin className="w-3.5 h-3.5" />
                        Location
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <User className="w-3.5 h-3.5" />
                        Worker
                      </div>
                    </TableHead>
                    <TableHead>
                      <div className="flex items-center gap-1">
                        <DollarSign className="w-3.5 h-3.5" />
                        Pay
                      </div>
                    </TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="w-[50px]"></TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredShifts.map((shift) => (
                    <TableRow key={shift.id}>
                      <TableCell className="font-medium">
                        {formatDate(shift.date)}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {shift.startTime} - {shift.endTime}
                      </TableCell>
                      <TableCell className="font-medium">{shift.role}</TableCell>
                      <TableCell>
                        <div>
                          <p className="text-sm">{shift.location}</p>
                          <p className="text-xs text-muted-foreground">
                            {shift.address}
                          </p>
                        </div>
                      </TableCell>
                      <TableCell>
                        {shift.worker ? (
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 bg-muted rounded-full flex items-center justify-center">
                              <span className="text-xs font-medium">
                                {shift.workerInitials}
                              </span>
                            </div>
                            <span className="text-sm">{shift.worker}</span>
                          </div>
                        ) : (
                          <span className="text-sm text-muted-foreground italic">
                            {shift.status === "recruiting"
                              ? "Finding worker..."
                              : shift.status === "cancelled"
                              ? "—"
                              : "Unassigned"}
                          </span>
                        )}
                      </TableCell>
                      <TableCell className="font-semibold text-accent">
                        ${shift.pay}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={shift.status} />
                      </TableCell>
                      <TableCell>
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon" className="h-8 w-8">
                              <MoreHorizontal className="w-4 h-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem>
                              <Eye className="w-4 h-4 mr-2" />
                              View Details
                            </DropdownMenuItem>
                            <DropdownMenuItem>
                              <Edit className="w-4 h-4 mr-2" />
                              Edit Shift
                            </DropdownMenuItem>
                            <DropdownMenuItem className="text-destructive">
                              <Trash2 className="w-4 h-4 mr-2" />
                              Cancel Shift
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {filteredShifts.length === 0 && (
              <div className="text-center py-12">
                <p className="text-muted-foreground">
                  No shifts found matching your filters.
                </p>
                <Button
                  variant="link"
                  onClick={() => {
                    setSearchQuery("");
                    setStatusFilter("all");
                    setRoleFilter("all");
                  }}
                >
                  Clear filters
                </Button>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </Suspense>
  );
}
