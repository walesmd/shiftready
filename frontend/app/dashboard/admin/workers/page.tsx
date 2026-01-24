"use client";

import { useEffect, useRef, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Building2,
  Calendar,
  CheckCircle2,
  Loader2,
  ShieldCheck,
  ShieldOff,
  User,
} from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { apiClient, type WorkerSummary } from "@/lib/api/client";

const STATUS_OPTIONS = [
  { value: "all", label: "All statuses" },
  { value: "active", label: "Active" },
  { value: "onboarding", label: "Onboarding" },
  { value: "inactive", label: "Inactive" },
];

const PER_PAGE = 12;

function formatDateTime(value?: string | null) {
  if (!value) {
    return "No completed shifts";
  }
  const date = new Date(value);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function renderStatusBadge(status: WorkerSummary["status"]) {
  switch (status) {
    case "active":
      return <Badge className="bg-emerald-100 text-emerald-700 hover:bg-emerald-100">Active</Badge>;
    case "onboarding":
      return <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">Onboarding</Badge>;
    case "inactive":
      return <Badge variant="secondary">Inactive</Badge>;
    default:
      return <Badge variant="secondary">Unknown</Badge>;
  }
}

export default function AdminWorkersPage() {
  const [workers, setWorkers] = useState<WorkerSummary[]>([]);
  const [statusFilter, setStatusFilter] = useState("all");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalWorkers, setTotalWorkers] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const lastRequestKeyRef = useRef<string | null>(null);

  useEffect(() => {
    const requestKey = `page:${page}:status:${statusFilter}:reload:${reloadKey}`;
    if (lastRequestKeyRef.current === requestKey) {
      return;
    }
    lastRequestKeyRef.current = requestKey;

    const loadWorkers = async () => {
      setLoading(true);
      setError(null);

      const response = await apiClient.getWorkers({
        page,
        per_page: PER_PAGE,
        status: statusFilter === "all" ? undefined : statusFilter,
      });

      if (response.error) {
        setError(response.error);
        setLoading(false);
        return;
      }

      const data = response.data;
      setWorkers(data?.workers ?? []);
      setTotalWorkers(data?.meta.total ?? 0);
      setTotalPages(Math.max(1, data?.meta.total_pages ?? 1));
      setLoading(false);
    };

    void loadWorkers();
  }, [page, reloadKey, statusFilter]);

  const handleStatusChange = (value: string) => {
    setPage(1);
    setStatusFilter(value);
  };

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Workers</h1>
          <p className="text-muted-foreground mt-1">
            Review worker activity, status, and recent shift history.
          </p>
        </div>
      </div>

      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="text-sm text-muted-foreground flex items-center gap-2">
              <span>Total workers:</span>
              <span className="font-medium text-foreground">{totalWorkers}</span>
            </div>
            <div className="flex-1 sm:flex-none sm:ml-auto min-w-[200px]">
              <Select value={statusFilter} onValueChange={handleStatusChange}>
                <SelectTrigger className="bg-card">
                  <SelectValue placeholder="Filter by status" />
                </SelectTrigger>
                <SelectContent>
                  {STATUS_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
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
          <Button onClick={() => setReloadKey((prev) => prev + 1)}>Retry</Button>
        </div>
      ) : (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <CardTitle className="text-lg font-semibold">All workers</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {workers.length === 0 ? (
              <div className="text-center py-10 text-muted-foreground">
                <User className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No workers match this filter.</p>
              </div>
            ) : (
              workers.map((worker) => {
                const lastShift = worker.last_shift;
                return (
                  <div
                    key={worker.id}
                    className="flex flex-col lg:flex-row lg:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                  >
                    <div className="flex-1 min-w-0 space-y-2">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h3 className="font-medium text-foreground">{worker.full_name}</h3>
                        {renderStatusBadge(worker.status)}
                      </div>
                      <div className="flex flex-wrap items-center gap-3 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <CheckCircle2 className="w-3.5 h-3.5" />
                          {worker.total_shifts_completed} completed shifts
                        </span>
                        <span className="flex items-center gap-1">
                          {worker.is_active ? (
                            <ShieldCheck className="w-3.5 h-3.5" />
                          ) : (
                            <ShieldOff className="w-3.5 h-3.5" />
                          )}
                          {worker.is_active ? "Active account" : "Inactive account"}
                        </span>
                      </div>
                      <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3.5 h-3.5" />
                          Last shift: {formatDateTime(lastShift?.date)}
                        </span>
                        {lastShift ? (
                          <>
                            <span className="flex items-center gap-1">
                              <User className="w-3.5 h-3.5" />
                              Role: {lastShift.role || lastShift.job_type || "Unknown role"}
                            </span>
                            <span className="flex items-center gap-1">
                              <Building2 className="w-3.5 h-3.5" />
                              {lastShift.company_name || "Unknown company"}
                            </span>
                          </>
                        ) : null}
                      </div>
                    </div>
                  </div>
                );
              })
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
