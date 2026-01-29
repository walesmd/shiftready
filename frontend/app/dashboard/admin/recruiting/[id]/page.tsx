"use client";

import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  ArrowRight,
  Building2,
  Calculator,
  Check,
  CheckCircle,
  Clock,
  Loader2,
  MapPin,
  Pause,
  Phone,
  Play,
  Send,
  User,
  UserX,
  X,
  Zap,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  apiClient,
  type RecruitingShiftDetail,
  type RecruitingShiftDetailResponse,
  type RecruitingSummary,
  type RecruitingTimelineEntry,
  type WorkerContactSummary,
} from "@/lib/api/client";

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

function getOutcomeBadge(outcome: string) {
  switch (outcome) {
    case "accepted":
      return (
        <Badge className="bg-green-100 text-green-700 hover:bg-green-100">
          Accepted
        </Badge>
      );
    case "declined":
      return (
        <Badge className="bg-red-100 text-red-700 hover:bg-red-100">
          Declined
        </Badge>
      );
    case "timeout":
      return (
        <Badge className="bg-amber-100 text-amber-700 hover:bg-amber-100">
          Timeout
        </Badge>
      );
    case "pending":
      return (
        <Badge className="bg-blue-100 text-blue-700 hover:bg-blue-100">
          Pending
        </Badge>
      );
    case "cancelled":
      return (
        <Badge className="bg-gray-100 text-gray-700 hover:bg-gray-100">
          Cancelled
        </Badge>
      );
    default:
      return <Badge variant="secondary">{outcome}</Badge>;
  }
}

function formatDateTime(dateString: string): string {
  if (!dateString) return "—";
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return "—";
  return date.toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
}

function formatTime(dateString: string): string {
  if (!dateString) return "—";
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return "—";
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true,
  });
}

function getIconForAction(icon: string) {
  const iconMap: Record<string, React.ReactNode> = {
    play: <Play className="w-4 h-4" />,
    pause: <Pause className="w-4 h-4" />,
    "check-circle": <CheckCircle className="w-4 h-4" />,
    calculator: <Calculator className="w-4 h-4" />,
    "user-x": <UserX className="w-4 h-4" />,
    send: <Send className="w-4 h-4" />,
    check: <Check className="w-4 h-4" />,
    x: <X className="w-4 h-4" />,
    clock: <Clock className="w-4 h-4" />,
    "arrow-right": <ArrowRight className="w-4 h-4" />,
  };
  return iconMap[icon] || <Zap className="w-4 h-4" />;
}

function getColorForAction(action: string): string {
  const colorMap: Record<string, string> = {
    recruiting_started: "bg-green-500",
    recruiting_paused: "bg-red-500",
    recruiting_resumed: "bg-green-500",
    recruiting_completed: "bg-blue-500",
    worker_scored: "bg-purple-500",
    worker_excluded: "bg-gray-500",
    offer_sent: "bg-blue-500",
    offer_accepted: "bg-green-500",
    offer_declined: "bg-red-500",
    offer_timeout: "bg-amber-500",
    next_worker_selected: "bg-purple-500",
  };
  return colorMap[action] || "bg-gray-500";
}

interface TimelineEntryProps {
  entry: RecruitingTimelineEntry;
  isLast: boolean;
}

function TimelineEntry({ entry, isLast }: TimelineEntryProps) {
  const [expanded, setExpanded] = useState(false);
  const hasDetails = entry.details && Object.keys(entry.details).length > 0;

  return (
    <div className="relative flex gap-4">
      {!isLast && (
        <div className="absolute left-4 top-8 w-0.5 h-full bg-border -translate-x-1/2" />
      )}
      <div
        className={`relative z-10 flex items-center justify-center w-8 h-8 rounded-full ${getColorForAction(
          entry.action
        )} text-white shrink-0`}
      >
        {getIconForAction(entry.icon)}
      </div>
      <div className="flex-1 pb-6">
        <div className="flex items-start justify-between gap-2">
          <div>
            <p className="font-medium text-foreground">{entry.label}</p>
            {entry.worker && (
              <p className="text-sm text-muted-foreground flex items-center gap-1 mt-0.5">
                <User className="w-3 h-3" />
                {entry.worker.name}
              </p>
            )}
          </div>
          <span className="text-xs text-muted-foreground whitespace-nowrap">
            {formatTime(entry.created_at)}
          </span>
        </div>

        {entry.assignment && (
          <div className="mt-2 text-sm text-muted-foreground flex flex-wrap gap-3">
            {entry.assignment.algorithm_score !== null && (
              <span>Score: {entry.assignment.algorithm_score.toFixed(2)}</span>
            )}
            {entry.assignment.distance_miles !== null && (
              <span>Distance: {entry.assignment.distance_miles.toFixed(1)} mi</span>
            )}
            <span>Status: {entry.assignment.status}</span>
          </div>
        )}

        {hasDetails && (
          <div className="mt-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setExpanded(!expanded)}
              className="h-6 px-2 text-xs"
            >
              {expanded ? "Hide details" : "Show details"}
            </Button>
            {expanded && (
              <pre className="mt-2 p-3 bg-muted rounded-md text-xs overflow-x-auto">
                {JSON.stringify(entry.details, null, 2)}
              </pre>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

interface WorkerCardProps {
  worker: WorkerContactSummary;
}

function WorkerCard({ worker }: WorkerCardProps) {
  return (
    <div className="p-4 bg-muted/50 rounded-lg space-y-3">
      <div className="flex items-start justify-between">
        <div>
          <h4 className="font-medium text-foreground">{worker.worker.name}</h4>
          <p className="text-sm text-muted-foreground flex items-center gap-1 mt-0.5">
            <Phone className="w-3 h-3" />
            {worker.worker.phone}
          </p>
        </div>
        {getOutcomeBadge(worker.outcome)}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
        <div>
          <p className="text-muted-foreground">Algorithm Score</p>
          <p className="font-medium">
            {worker.algorithm_score !== null
              ? worker.algorithm_score.toFixed(2)
              : "N/A"}
          </p>
        </div>
        <div>
          <p className="text-muted-foreground">Distance</p>
          <p className="font-medium">
            {worker.distance_miles !== null
              ? `${worker.distance_miles.toFixed(1)} mi`
              : "N/A"}
          </p>
        </div>
        <div>
          <p className="text-muted-foreground">Response Time</p>
          <p className="font-medium">
            {worker.response_time_minutes !== null
              ? `${worker.response_time_minutes} min`
              : "No response"}
          </p>
        </div>
        <div>
          <p className="text-muted-foreground">Response Method</p>
          <p className="font-medium capitalize">
            {worker.response_method || "N/A"}
          </p>
        </div>
      </div>

      {worker.decline_reason && (
        <div className="text-sm">
          <p className="text-muted-foreground">Decline Reason</p>
          <p className="font-medium text-red-600">{worker.decline_reason}</p>
        </div>
      )}

      <div className="text-xs text-muted-foreground">
        Offer sent:{" "}
        {worker.offer_sent_at ? formatDateTime(worker.offer_sent_at) : "N/A"}
        {worker.response_received_at && (
          <>
            {" "}
            | Response: {formatDateTime(worker.response_received_at)}
          </>
        )}
      </div>
    </div>
  );
}

export default function AdminRecruitingDetailPage() {
  const params = useParams();
  const shiftId = Number(params.id);

  const [data, setData] = useState<RecruitingShiftDetailResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!shiftId || isNaN(shiftId)) {
      setError("Invalid shift ID");
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const response = await apiClient.getAdminRecruitingDetail(shiftId);

      if (response.error) {
        setError(response.error);
        return;
      }

      setData(response.data);
    } catch (err) {
      console.error("Failed to load recruiting detail", err);
      setError("Failed to load recruiting data");
    } finally {
      setLoading(false);
    }
  }, [shiftId]);

  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  if (loading) {
    return (
      <div className="p-4 lg:p-8 flex items-center justify-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (error || !data) {
    return (
      <div className="p-4 lg:p-8">
        <div className="flex flex-col items-center justify-center min-h-[400px] text-center gap-4">
          <p className="text-sm text-muted-foreground">
            {error || "Failed to load data"}
          </p>
          <div className="flex gap-2">
            <Button variant="outline" asChild>
              <Link href="/dashboard/admin/recruiting">
                <ArrowLeft className="w-4 h-4 mr-2" />
                Back to list
              </Link>
            </Button>
            <Button onClick={fetchData}>Retry</Button>
          </div>
        </div>
      </div>
    );
  }

  const { shift, summary, timeline, workers_contacted } = data;

  return (
    <div className="p-4 lg:p-8 space-y-6">
      <div className="flex items-center gap-4">
        <Button variant="ghost" size="sm" asChild>
          <Link href="/dashboard/admin/recruiting">
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back
          </Link>
        </Button>
      </div>

      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 flex-wrap">
            <h1 className="text-2xl font-bold text-foreground">{shift.title}</h1>
            {getRecruitingStatusBadge(shift.recruiting_status)}
          </div>
          <p className="text-muted-foreground mt-1 font-mono text-sm">
            {shift.tracking_code}
          </p>
        </div>
      </div>

      {/* Shift Info Card */}
      <Card>
        <CardContent className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="flex items-start gap-3">
              <Building2 className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <p className="text-sm text-muted-foreground">Company</p>
                <p className="font-medium">{shift.company.name}</p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <MapPin className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <p className="text-sm text-muted-foreground">Location</p>
                <p className="font-medium">{shift.work_location.name}</p>
                <p className="text-sm text-muted-foreground">
                  {shift.work_location.city}, {shift.work_location.state}
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <Clock className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <p className="text-sm text-muted-foreground">Schedule</p>
                <p className="font-medium">{shift.schedule.formatted_range}</p>
                <p className="text-sm text-muted-foreground">
                  {shift.schedule.duration_hours} hours
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <User className="w-5 h-5 text-muted-foreground mt-0.5" />
              <div>
                <p className="text-sm text-muted-foreground">Slots</p>
                <p className="font-medium">
                  {shift.capacity.slots_filled} / {shift.capacity.slots_total}{" "}
                  filled
                </p>
                <p className="text-sm text-accent">
                  {shift.pay.formatted_rate}
                </p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Summary Stats */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-blue-600">
              {summary.offers_sent}
            </p>
            <p className="text-sm text-muted-foreground">Offers Sent</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-green-600">
              {summary.offers_accepted}
            </p>
            <p className="text-sm text-muted-foreground">Accepted</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-red-600">
              {summary.offers_declined}
            </p>
            <p className="text-sm text-muted-foreground">Declined</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-amber-600">
              {summary.offers_timeout}
            </p>
            <p className="text-sm text-muted-foreground">Timeouts</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-purple-600">
              {summary.workers_scored}
            </p>
            <p className="text-sm text-muted-foreground">Workers Scored</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4 text-center">
            <p className="text-2xl font-bold text-gray-600">
              {summary.workers_excluded}
            </p>
            <p className="text-sm text-muted-foreground">Excluded</p>
          </CardContent>
        </Card>
      </div>

      {summary.is_paused && summary.pause_reason && (
        <Card className="border-red-200 bg-red-50">
          <CardContent className="p-4">
            <div className="flex items-center gap-2 text-red-700">
              <Pause className="w-5 h-5" />
              <span className="font-medium">Recruiting Paused</span>
            </div>
            <p className="text-sm text-red-600 mt-1">
              Reason: {summary.pause_reason}
            </p>
          </CardContent>
        </Card>
      )}

      {/* Tabs for Timeline and Workers */}
      <Tabs defaultValue="timeline">
        <TabsList>
          <TabsTrigger value="timeline">
            <Clock className="w-4 h-4 mr-1" />
            Timeline ({timeline.length})
          </TabsTrigger>
          <TabsTrigger value="workers">
            <User className="w-4 h-4 mr-1" />
            Workers Contacted ({workers_contacted.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="timeline">
          <Card>
            <CardHeader>
              <CardTitle>Recruiting Timeline</CardTitle>
            </CardHeader>
            <CardContent>
              {timeline.length === 0 ? (
                <p className="text-center py-8 text-muted-foreground">
                  No activity recorded yet.
                </p>
              ) : (
                <div className="space-y-0">
                  {timeline.map((entry, index) => (
                    <TimelineEntry
                      key={entry.id}
                      entry={entry}
                      isLast={index === timeline.length - 1}
                    />
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="workers">
          <Card>
            <CardHeader>
              <CardTitle>Workers Contacted</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {workers_contacted.length === 0 ? (
                <p className="text-center py-8 text-muted-foreground">
                  No workers have been contacted yet.
                </p>
              ) : (
                workers_contacted.map((worker) => (
                  <WorkerCard key={worker.id} worker={worker} />
                ))
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
