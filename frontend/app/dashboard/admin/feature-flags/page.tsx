"use client";

import { useEffect, useRef, useState } from "react";
import { useDebounce } from "@/hooks/use-debounce";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  AlertCircle,
  Archive,
  Calendar,
  Edit2,
  Flag,
  Loader2,
  Plus,
  RotateCcw,
  Search,
} from "lucide-react";
import { apiClient, type FeatureFlag } from "@/lib/api/client";
import { FeatureFlagModal } from "./feature-flag-modal";
import { toast } from "sonner";

const STATUS_OPTIONS = [
  { value: "active", label: "Active" },
  { value: "archived", label: "Archived" },
];

const PER_PAGE = 20;

function formatDateTime(value?: string | null) {
  if (!value) return "Never";
  const date = new Date(value);
  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function renderValueTypeBadge(valueType: FeatureFlag["value_type"]) {
  switch (valueType) {
    case "boolean":
      return <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">Boolean</Badge>;
    case "string":
      return <Badge className="bg-purple-100 text-purple-700 hover:bg-purple-100">String</Badge>;
    case "number":
      return <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">Number</Badge>;
    case "array":
      return <Badge className="bg-emerald-100 text-emerald-700 hover:bg-emerald-100">Array</Badge>;
    case "object":
      return <Badge className="bg-rose-100 text-rose-700 hover:bg-rose-100">Object</Badge>;
    default:
      return <Badge variant="secondary">Unknown</Badge>;
  }
}

function renderValueDisplay(flag: FeatureFlag) {
  if (flag.value_type === "boolean") {
    return null; // Handled by the switch
  }
  if (flag.value_type === "string") {
    const strVal = String(flag.value);
    return (
      <span className="text-sm font-mono bg-muted px-2 py-0.5 rounded">
        {strVal.length > 50 ? strVal.substring(0, 50) + "..." : strVal}
      </span>
    );
  }
  if (flag.value_type === "number") {
    return (
      <span className="text-sm font-mono bg-muted px-2 py-0.5 rounded">
        {String(flag.value)}
      </span>
    );
  const jsonStr = JSON.stringify(flag.value);
  return (
    <span className="text-sm font-mono bg-muted px-2 py-0.5 rounded">
      {jsonStr.length > 50 ? jsonStr.substring(0, 50) + "..." : jsonStr}
    </span>
  );
}
}

export default function AdminFeatureFlagsPage() {
  const [flags, setFlags] = useState<FeatureFlag[]>([]);
  const [statusFilter, setStatusFilter] = useState("active");
  const [searchInput, setSearchInput] = useState("");
  const debouncedSearch = useDebounce(searchInput, 300);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalFlags, setTotalFlags] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const lastRequestKeyRef = useRef<string | null>(null);
  const [togglingId, setTogglingId] = useState<number | null>(null);

  // Modal state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingFlag, setEditingFlag] = useState<FeatureFlag | null>(null);

  useEffect(() => {
    const requestKey = `page:${page}:status:${statusFilter}:search:${debouncedSearch}:reload:${reloadKey}`;
    if (lastRequestKeyRef.current === requestKey) {
      return;
    }
    lastRequestKeyRef.current = requestKey;

    const loadFlags = async () => {
      setLoading(true);
      setError(null);

      const response = await apiClient.getFeatureFlags({
        page,
        per_page: PER_PAGE,
        status: statusFilter as "active" | "archived",
        search: debouncedSearch || undefined,
      });

      if (response.error) {
        setError(response.error);
        setLoading(false);
        return;
      }

      const data = response.data;
      setFlags(data?.feature_flags ?? []);
      setTotalFlags(data?.meta.total ?? 0);
      setTotalPages(Math.max(1, data?.meta.total_pages ?? 1));
      setLoading(false);
    };

    void loadFlags();
  }, [page, reloadKey, statusFilter, debouncedSearch]);

  const handleStatusChange = (value: string) => {
    setPage(1);
    setStatusFilter(value);
    lastRequestKeyRef.current = null;
  };

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setSearchInput(e.target.value);
    setPage(1);
    lastRequestKeyRef.current = null;
  };

  const handleToggle = async (flag: FeatureFlag) => {
    if (!flag.value_type || flag.value_type !== "boolean") return;

    setTogglingId(flag.id);
    const response = await apiClient.toggleFeatureFlag(flag.id);
    setTogglingId(null);

    if (response.error) {
      toast.error(`Failed to toggle flag: ${response.error}`);
      return;
    }

    const updatedFlag = response.data?.feature_flag;
    if (!updatedFlag) {
      toast.error("Failed to toggle flag: Invalid response");
      return;
    }

    setFlags((prev) =>
      prev.map((f) => (f.id === flag.id ? updatedFlag : f))
    );
    toast.success(`Flag "${flag.key}" ${updatedFlag.value ? "enabled" : "disabled"}`);
  };

  const handleArchive = async (flag: FeatureFlag) => {
    const response = await apiClient.archiveFeatureFlag(flag.id);

    if (response.error) {
      toast.error(`Failed to archive flag: ${response.error}`);
      return;
    }

    lastRequestKeyRef.current = null;
    setReloadKey((prev) => prev + 1);
    toast.success(`Flag "${flag.key}" archived`);
  };

  const handleRestore = async (flag: FeatureFlag) => {
    const response = await apiClient.restoreFeatureFlag(flag.id);

    if (response.error) {
      toast.error(`Failed to restore flag: ${response.error}`);
      return;
    }

    lastRequestKeyRef.current = null;
    setReloadKey((prev) => prev + 1);
    toast.success(`Flag "${flag.key}" restored`);
  };

  const handleCreateClick = () => {
    setEditingFlag(null);
    setIsModalOpen(true);
  };

  const handleEditClick = (flag: FeatureFlag) => {
    setEditingFlag(flag);
    setIsModalOpen(true);
  };

  const handleModalClose = () => {
    setIsModalOpen(false);
    setEditingFlag(null);
  };

  const handleModalSave = () => {
    lastRequestKeyRef.current = null;
    setReloadKey((prev) => prev + 1);
    setIsModalOpen(false);
    setEditingFlag(null);
  };

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Feature Flags</h1>
          <p className="text-muted-foreground mt-1">
            Control feature rollouts and application behavior.
          </p>
        </div>
        <Button onClick={handleCreateClick}>
          <Plus className="w-4 h-4 mr-2" />
          Add Flag
        </Button>
      </div>

      <Card>
        <CardContent className="p-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <Input
                placeholder="Search by key or description..."
                value={searchInput}
                onChange={handleSearchChange}
                className="pl-9"
              />
            </div>
            <div className="flex items-center gap-4">
              <div className="text-sm text-muted-foreground flex items-center gap-2">
                <span>Total:</span>
                <span className="font-medium text-foreground">{totalFlags}</span>
              </div>
              <div className="min-w-[150px]">
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
          </div>
        </CardContent>
      </Card>

      {loading ? (
        <div className="p-4 lg:p-8 flex items-center justify-center min-h-[300px]">
          <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
        </div>
      ) : error ? (
        <div className="p-4 lg:p-8 flex flex-col items-center justify-center min-h-[300px] text-center gap-4">
          <AlertCircle className="w-12 h-12 text-muted-foreground opacity-50" />
          <p className="text-sm text-muted-foreground">{error}</p>
          <Button onClick={() => setReloadKey((prev) => prev + 1)}>Retry</Button>
        </div>
      ) : (
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-4">
            <CardTitle className="text-lg font-semibold">
              {statusFilter === "archived" ? "Archived Flags" : "Active Flags"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {flags.length === 0 ? (
              <div className="text-center py-10 text-muted-foreground">
                <Flag className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No feature flags found.</p>
                {statusFilter === "active" && (
                  <Button variant="outline" className="mt-4" onClick={handleCreateClick}>
                    <Plus className="w-4 h-4 mr-2" />
                    Create your first flag
                  </Button>
                )}
              </div>
            ) : (
              flags.map((flag) => (
                <div
                  key={flag.id}
                  className="flex flex-col lg:flex-row lg:items-center justify-between p-4 bg-muted/50 rounded-lg gap-4"
                >
                  <div className="flex-1 min-w-0 space-y-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h3 className="font-mono font-medium text-foreground">{flag.key}</h3>
                      {renderValueTypeBadge(flag.value_type)}
                      {flag.archived && (
                        <Badge variant="secondary">Archived</Badge>
                      )}
                    </div>
                    {flag.description && (
                      <p className="text-sm text-muted-foreground">{flag.description}</p>
                    )}
                    <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Calendar className="w-3 h-3" />
                        Updated: {formatDateTime(flag.updated_at)}
                      </span>
                      {renderValueDisplay(flag)}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {flag.value_type === "boolean" && !flag.archived && (
                      <div className="flex items-center gap-2">
                        <Switch
                          checked={flag.value === true}
                          onCheckedChange={() => handleToggle(flag)}
                          disabled={togglingId === flag.id}
                        />
                        <span className="text-sm text-muted-foreground min-w-[60px]">
                          {flag.value ? "Enabled" : "Disabled"}
                        </span>
                      </div>
                    )}
                    <div className="flex items-center gap-2">
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleEditClick(flag)}
                      >
                        <Edit2 className="w-4 h-4" />
                      </Button>
                      {flag.archived ? (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleRestore(flag)}
                        >
                          <RotateCcw className="w-4 h-4" />
                        </Button>
                      ) : (
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => handleArchive(flag)}
                        >
                          <Archive className="w-4 h-4" />
                        </Button>
                      )}
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

      <FeatureFlagModal
        open={isModalOpen}
        onClose={handleModalClose}
        onSave={handleModalSave}
        flag={editingFlag}
      />
    </div>
  );
}
