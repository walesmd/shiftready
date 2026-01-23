"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Building2,
  Calendar,
  Clock,
  Loader2,
  MapPin,
  Users,
  User,
} from "lucide-react";
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
import { apiClient, type Company, type Shift } from "@/lib/api/client";

const STATUS_OPTIONS = [
  { value: "all", label: "All statuses" },
  { value: "posted", label: "Posted" },
  { value: "pending", label: "Pending" },
  { value: "recruiting", label: "Recruiting" },
  { value: "filled", label: "Filled" },
  { value: "confirmed", label: "Confirmed" },
  { value: "in_progress", label: "In progress" },
  { value: "completed", label: "Completed" },
  { value: "cancelled", label: "Cancelled" },
];

const PER_PAGE = 12;

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
      return <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">Pending</Badge>;
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
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function formatTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

export default function AdminShiftsPage() {
  const [shifts, setShifts] = useState<Shift[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [selectedCompany, setSelectedCompany] = useState("all");
  const [selectedStatus, setSelectedStatus] = useState("all");
  const [selectedDate, setSelectedDate] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalShifts, setTotalShifts] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const handleCompanyChange = (value: string) => {
    setPage(1);
    setSelectedCompany(value);
  };

  const handleStatusChange = (value: string) => {
    setPage(1);
    setSelectedStatus(value);
  };

  const handleDateChange = (value: string) => {
    setPage(1);
    setSelectedDate(value);
  };

  const handleClearFilters = () => {
    setSelectedCompany("all");
    setSelectedStatus("all");
    setSelectedDate("");
    setPage(1);
  };

  const filteredCompanyId = useMemo(() => {
    if (selectedCompany === "all") {
      return undefined;
    }
    const parsed = Number(selectedCompany);
    return Number.isNaN(parsed) ? undefined : parsed;
  }, [selectedCompany]);

  const fetchCompanies = useCallback(async () => {
    const companiesResponse = await apiClient.getCompanies();
    if (companiesResponse.data) {
      setCompanies(companiesResponse.data.companies);
    }
  }, []);

  const fetchShifts = useCallback(async () => {
    setLoading(true);
    setError(null);

    const startDateIso = selectedDate
      ? new Date(`${selectedDate}T00:00:00`).toISOString()
      : undefined;
    const endDateIso = selectedDate
      ? new Date(`${selectedDate}T23:59:59`).toISOString()
      : undefined;

    const shiftsResponse = await apiClient.getShifts({
      company_id: filteredCompanyId,
      status: selectedStatus === "all" ? undefined : selectedStatus,
      start_date: startDateIso,
      end_date: endDateIso,
      page,
      per_page: PER_PAGE,
      direction: "desc",
    });

    if (shiftsResponse.error) {
      setError(shiftsResponse.error);
      setLoading(false);
      return;
    }

    const data = shiftsResponse.data;
    const nextTotalPages = Math.max(1, data?.meta.total_pages ?? 1);
    setShifts(data?.shifts ?? []);
    setTotalShifts(data?.meta.total ?? 0);
    setTotalPages(nextTotalPages);
    setLoading(false);
  }, [filteredCompanyId, page, selectedStatus, selectedDate]);

  useEffect(() => {
    fetchCompanies().catch((fetchError) => {
      console.error("Failed to load companies", fetchError);
    });
  }, [fetchCompanies]);

  useEffect(() => {
    fetchShifts().catch((fetchError) => {
      console.error("Failed to load shifts", fetchError);
      setError("Failed to load shifts");
      setLoading(false);
    });
  }, [fetchShifts]);

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">All shifts</h1>
          <p className="text-muted-foreground mt-1">
            Monitor every shift across companies and statuses.
          </p>
        </div>
      </div>

      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col lg:flex-row lg:items-end gap-4">
            <div className="flex-1">
              <label htmlFor="company-filter" className="text-sm font-medium text-foreground">Company</label>
              <Select value={selectedCompany} onValueChange={handleCompanyChange}>
                <SelectTrigger id="company-filter" className="mt-2 bg-card">
                  <SelectValue placeholder="All companies" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All companies</SelectItem>
                  {companies.length === 0 ? (
                    <SelectItem value="none" disabled>
                      No companies available
                    </SelectItem>
                  ) : (
                    companies.map((company) => (
                      <SelectItem key={company.id} value={company.id.toString()}>
                        {company.name}
                      </SelectItem>
                    ))
                  )}
                </SelectContent>
              </Select>
            </div>

            <div className="flex-1">
              <label className="text-sm font-medium text-foreground">Status</label>
              <Select value={selectedStatus} onValueChange={handleStatusChange}>
                <SelectTrigger className="mt-2 bg-card">
                  <SelectValue placeholder="All statuses" />
                </SelectTrigger>
                <SelectContent>
                  {STATUS_OPTIONS.map((status) => (
                    <SelectItem key={status.value} value={status.value}>
                      {status.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="flex-1">
              <label className="text-sm font-medium text-foreground">Shift date</label>
              <Input
                type="date"
                value={selectedDate}
                onChange={(event) => handleDateChange(event.target.value)}
                className="mt-2 bg-card"
                aria-label="Shift date"
              />
            </div>

            <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
              <div className="text-sm text-muted-foreground flex items-center gap-2">
                <span>Total shifts:</span>
                <span className="font-medium text-foreground">{totalShifts}</span>
              </div>
              <Button variant="outline" onClick={handleClearFilters}>
                Clear filters
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {loading ? (
        <div className="p-4 lg:p-8 flex items-center justify-center min-h-[300px]">
          <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
        </div>
      ) : error ? (
        <div className="p-4 lg:p-8 flex flex-col items-center justify-center min-h-[300px] text-center gap-4">
          <p className="text-sm text-muted-foreground">{error}</p>
          <Button onClick={fetchShifts}>Retry</Button>
        </div>
      ) : (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <CardTitle className="text-lg font-semibold">All shifts</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {shifts.length === 0 ? (
              <div className="text-center py-10 text-muted-foreground">
                <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No shifts match these filters.</p>
              </div>
            ) : (
              shifts.map((shift) => (
                <div
                  key={shift.id}
                  className="flex flex-col lg:flex-row lg:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                >
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-medium text-foreground">{shift.title}</h3>
                      {getShiftStatusBadge(shift.status)}
                    </div>
                    <p className="text-sm text-muted-foreground mt-1 flex items-center gap-2">
                      <Building2 className="w-4 h-4" />
                      {shift.company.name}
                    </p>
                    <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-4 mt-2 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <MapPin className="w-3.5 h-3.5" />
                        {shift.work_location.name},{" "}
                        {shift.work_location.city}, {shift.work_location.state}
                      </span>
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {formatDate(shift.schedule.start_datetime)}{" "}
                        {formatTime(shift.schedule.start_datetime)} -{" "}
                        {formatTime(shift.schedule.end_datetime)}
                      </span>
                    </div>
                    <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-4 mt-2 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <User className="w-3.5 h-3.5" />
                        {shift.created_by.name}
                      </span>
                      <span className="flex items-center gap-1">
                        <Users className="w-3.5 h-3.5" />
                        {shift.capacity.slots_filled}/{shift.capacity.slots_total} filled
                      </span>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-foreground">
                      {shift.pay.formatted_rate}
                    </p>
                    <p className="text-sm text-accent font-semibold">
                      {shift.capacity.slots_available} slots open
                    </p>
                  </div>
                </div>
              ))
            )}
          </CardContent>
        </Card>
      )}

      {!loading && !error && totalPages > 1 && (
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div className="text-sm text-muted-foreground">
            Page <span className="font-medium text-foreground">{page}</span> of{" "}
            <span className="font-medium text-foreground">{totalPages}</span>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              onClick={() => setPage((prev) => Math.max(1, prev - 1))}
              disabled={page <= 1}
            >
              Previous
            </Button>
            <Button
              variant="outline"
              onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
              disabled={page >= totalPages}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
