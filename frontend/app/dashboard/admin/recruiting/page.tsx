"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  AlertTriangle,
  Building2,
  Calendar,
  Check,
  Clock,
  Loader2,
  MapPin,
  Pause,
  Send,
  X,
  Zap,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  apiClient,
  type Company,
  type RecruitingShiftSummary,
} from "@/lib/api/client";

const RECRUITING_STATUS_OPTIONS = [
  { value: "all", label: "All statuses" },
  { value: "paused", label: "Paused" },
  { value: "active", label: "Active" },
  { value: "filled", label: "Filled" },
  { value: "completed", label: "Completed" },
];

const PER_PAGE = 20;

function getRecruitingStatusBadge(status: string) {
  switch (status) {
    case "paused":
      return (
        <Badge className="bg-red-100 text-red-700 hover:bg-red-100">
          <Pause className="w-3 h-3 mr-1" />
          Paused
        </Badge>
      );
    case "active":
      return (
        <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
          <Zap className="w-3 h-3 mr-1" />
          Active
        </Badge>
      );
    case "filled":
      return (
        <Badge className="bg-green-100 text-green-700 hover:bg-green-100">
          <Check className="w-3 h-3 mr-1" />
          Filled
        </Badge>
      );
    default:
      return <Badge variant="secondary">{status}</Badge>;
  }
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function formatTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

function formatRelativeTime(dateString: string | null): string {
  if (!dateString) return "No activity";
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMins < 1) return "Just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  return `${diffDays}d ago`;
}

export default function AdminRecruitingPage() {
  const [shifts, setShifts] = useState<RecruitingShiftSummary[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [selectedCompany, setSelectedCompany] = useState("all");
  const [selectedStatus, setSelectedStatus] = useState("all");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalShifts, setTotalShifts] = useState(0);
  const [pausedCount, setPausedCount] = useState(0);
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

  const handleClearFilters = () => {
    setSelectedCompany("all");
    setSelectedStatus("all");
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
    try {
      const companiesResponse = await apiClient.getCompanies();
      if (companiesResponse.data) {
        setCompanies(companiesResponse.data.companies);
      }
    } catch (err) {
      console.error("Failed to load companies", err);
    }
  }, []);

  const fetchShifts = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await apiClient.getAdminRecruitingShifts({
        company_id: filteredCompanyId,
        status:
          selectedStatus === "all"
            ? undefined
            : (selectedStatus as "paused" | "active" | "filled" | "completed"),
        page,
        per_page: PER_PAGE,
      });

      if (response.error) {
        setError(response.error);
        return;
      }

      const data = response.data;
      setShifts(data?.shifts ?? []);
      setTotalShifts(data?.meta.total ?? 0);
      setTotalPages(Math.max(1, data?.meta.total_pages ?? 1));
      setPausedCount(data?.meta.paused_count ?? 0);
    } catch (err) {
      console.error("Failed to load recruiting shifts", err);
      setError("Failed to load recruiting data");
    } finally {
      setLoading(false);
    }
  }, [filteredCompanyId, selectedStatus, page]);

  useEffect(() => {
    void fetchCompanies();
  }, [fetchCompanies]);

  useEffect(() => {
    void fetchShifts();
  }, [fetchShifts]);

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">
            Recruiting Monitor
          </h1>
          <p className="text-muted-foreground mt-1">
            Observe the recruiting algorithm across all shifts.
          </p>
        </div>
      </div>

      {pausedCount > 0 && (
        <Alert variant="destructive">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle>Attention Required</AlertTitle>
          <AlertDescription>
            {pausedCount} shift{pausedCount !== 1 ? "s have" : " has"} paused
            recruiting. These shifts may need manual intervention or have run
            out of available workers.
          </AlertDescription>
        </Alert>
      )}

      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col lg:flex-row lg:items-end gap-4">
            <div className="flex-1">
              <label
                htmlFor="company-filter"
                className="text-sm font-medium text-foreground"
              >
                Company
              </label>
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
              <label className="text-sm font-medium text-foreground">
                Recruiting Status
              </label>
              <Select value={selectedStatus} onValueChange={handleStatusChange}>
                <SelectTrigger className="mt-2 bg-card">
                  <SelectValue placeholder="All statuses" />
                </SelectTrigger>
                <SelectContent>
                  {RECRUITING_STATUS_OPTIONS.map((status) => (
                    <SelectItem key={status.value} value={status.value}>
                      {status.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
              <div className="text-sm text-muted-foreground flex items-center gap-2">
                <span>Total:</span>
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
            <CardTitle className="text-lg font-semibold">
              Shifts with Recruiting Activity
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {shifts.length === 0 ? (
              <div className="text-center py-10 text-muted-foreground">
                <Calendar className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No shifts with recruiting activity found.</p>
              </div>
            ) : (
              shifts.map((shift) => (
                <Link
                  key={shift.id}
                  href={`/dashboard/admin/recruiting/${shift.id}`}
                  className="block"
                >
                  <div
                    className={`flex flex-col lg:flex-row lg:items-center justify-between p-4 rounded-lg gap-4 transition-colors hover:bg-muted ${
                      shift.recruiting_status === "paused"
                        ? "bg-red-50 border border-red-200"
                        : "bg-muted/50"
                    }`}
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-medium text-foreground">
                          {shift.title}
                        </h3>
                        {getRecruitingStatusBadge(shift.recruiting_status)}
                        <span className="text-xs text-muted-foreground font-mono">
                          {shift.tracking_code}
                        </span>
                      </div>
                      <p className="text-sm text-muted-foreground mt-1 flex items-center gap-2">
                        <Building2 className="w-4 h-4" />
                        {shift.company.name}
                      </p>
                      <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-4 mt-2 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5" />
                          {shift.work_location.city}, {shift.work_location.state}
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="w-3.5 h-3.5" />
                          {formatDate(shift.schedule.start_datetime)}{" "}
                          {formatTime(shift.schedule.start_datetime)}
                        </span>
                      </div>

                      <div className="flex items-center gap-4 mt-3">
                        <div className="flex items-center gap-1 text-sm">
                          <Send className="w-3.5 h-3.5 text-blue-500" />
                          <span className="text-muted-foreground">Sent:</span>
                          <span className="font-medium">
                            {shift.stats.offers_sent}
                          </span>
                        </div>
                        <div className="flex items-center gap-1 text-sm">
                          <Check className="w-3.5 h-3.5 text-green-500" />
                          <span className="text-muted-foreground">Accepted:</span>
                          <span className="font-medium">
                            {shift.stats.offers_accepted}
                          </span>
                        </div>
                        <div className="flex items-center gap-1 text-sm">
                          <X className="w-3.5 h-3.5 text-red-500" />
                          <span className="text-muted-foreground">Declined:</span>
                          <span className="font-medium">
                            {shift.stats.offers_declined}
                          </span>
                        </div>
                        <div className="flex items-center gap-1 text-sm">
                          <Clock className="w-3.5 h-3.5 text-amber-500" />
                          <span className="text-muted-foreground">Timeout:</span>
                          <span className="font-medium">
                            {shift.stats.offers_timeout}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div className="text-right space-y-1">
                      <p className="text-sm font-medium text-foreground">
                        {shift.pay.formatted_rate}
                      </p>
                      <p className="text-sm">
                        <span className="text-accent font-semibold">
                          {shift.capacity.slots_filled}
                        </span>
                        <span className="text-muted-foreground">
                          /{shift.capacity.slots_total} filled
                        </span>
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatRelativeTime(shift.last_activity_at)}
                      </p>
                    </div>
                  </div>
                </Link>
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
