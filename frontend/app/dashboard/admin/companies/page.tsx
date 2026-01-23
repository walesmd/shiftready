"use client";

import { useEffect, useRef, useState } from "react";
import { Building2, Calendar, Loader2, Users } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { apiClient, type Company } from "@/lib/api/client";

const PER_PAGE = 12;

function formatDateTime(value?: string | null) {
  if (!value) {
    return "No shifts yet";
  }
  const date = new Date(value);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function renderActiveBadges(company: Company) {
  const summary = company.shift_summary;
  if (!summary || summary.active === 0) {
    return <Badge variant="secondary">No active shifts</Badge>;
  }

  const badges: Array<{ key: string; label: string; count: number }> = [
    { key: "posted", label: "Pending", count: summary.by_status.posted },
    { key: "recruiting", label: "Recruiting", count: summary.by_status.recruiting },
    { key: "in_progress", label: "In progress", count: summary.by_status.in_progress },
  ];

  return badges
    .filter((badge) => badge.count > 0)
    .map((badge) => (
      <Badge key={badge.key} className="bg-amber-100 text-amber-700 hover:bg-amber-100">
        {badge.label} · {badge.count}
      </Badge>
    ));
}

export default function AdminCompaniesPage() {
  const [companies, setCompanies] = useState<Company[]>([]);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCompanies, setTotalCompanies] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const lastRequestKeyRef = useRef<string | null>(null);

  useEffect(() => {
    const requestKey = `page:${page}:reload:${reloadKey}`;
    if (lastRequestKeyRef.current === requestKey) {
      return;
    }
    lastRequestKeyRef.current = requestKey;

    const loadCompanies = async () => {
      setLoading(true);
      setError(null);

      try {
        const response = await apiClient.getCompanies({ page, per_page: PER_PAGE });
        if (response.error) {
          setError(response.error);
          return;
        }

        const data = response.data;
        setCompanies(data?.companies ?? []);
        setTotalCompanies(data?.meta.total ?? 0);
        setTotalPages(Math.max(1, data?.meta.total_pages ?? 1));
      } catch (err) {
        console.error("Failed to load companies", err);
        setError("Failed to load companies");
      } finally {
        setLoading(false);
      }
    };

    void loadCompanies();
  }, [page, reloadKey]);

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Companies</h1>
          <p className="text-muted-foreground mt-1">
            Track all companies and their current shift activity.
          </p>
        </div>
      </div>

      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="text-sm text-muted-foreground flex items-center gap-2">
              <span>Total companies:</span>
              <span className="font-medium text-foreground">{totalCompanies}</span>
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
            <CardTitle className="text-lg font-semibold">All companies</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {companies.length === 0 ? (
              <div className="text-center py-10 text-muted-foreground">
                <Building2 className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No companies found.</p>
              </div>
            ) : (
              companies.map((company) => (
                <div
                  key={company.id}
                  className="flex flex-col lg:flex-row lg:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                >
                  <div className="flex-1 min-w-0 space-y-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-medium text-foreground">{company.name}</h3>
                      {company.industry && (
                        <Badge variant="secondary">{company.industry}</Badge>
                      )}
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                      {renderActiveBadges(company)}
                    </div>
                    <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4 text-sm text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Users className="w-3.5 h-3.5" />
                        {company.shift_summary?.total ?? 0} total shifts
                      </span>
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3.5 h-3.5" />
                        Last requested: {formatDateTime(company.last_shift_requested_at)}
                      </span>
                    </div>
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
