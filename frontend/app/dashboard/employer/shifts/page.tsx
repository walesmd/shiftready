"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  ArrowLeft,
  Calendar,
  Clock,
  DollarSign,
  Users,
  MapPin,
  Receipt,
  Loader2,
  CheckCircle2,
  AlertCircle,
  Building2,
} from "lucide-react";
import { apiClient, type WorkLocation } from "@/lib/api/client";
import { toast } from "sonner";

const JOB_TYPES = [
  { value: "warehouse", label: "Warehouse" },
  { value: "moving", label: "Moving" },
  { value: "event_setup", label: "Event Setup" },
  { value: "event_teardown", label: "Event Teardown" },
  { value: "packing", label: "Packing" },
  { value: "loading", label: "Loading" },
  { value: "unloading", label: "Unloading" },
  { value: "assembly", label: "Assembly" },
  { value: "construction", label: "Construction" },
  { value: "landscaping", label: "Landscaping" },
  { value: "delivery", label: "Delivery" },
  { value: "retail", label: "Retail" },
  { value: "hospitality", label: "Hospitality" },
  { value: "cleaning", label: "Cleaning" },
  { value: "general_labor", label: "General Labor" },
];

const SERVICE_FEE_RATE = 0.20; // 20% service fee

interface FormData {
  title: string;
  description: string;
  jobType: string;
  workLocationId: string;
  date: string;
  startTime: string;
  endTime: string;
  payRate: string;
  workersNeeded: string;
  skillsRequired: string;
  physicalRequirements: string;
}

export default function CreateShiftPage() {
  const router = useRouter();
  const [workLocations, setWorkLocations] = useState<WorkLocation[]>([]);
  const [loading, setLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [createdTrackingCode, setCreatedTrackingCode] = useState<string | null>(null);
  const hasFetchedRef = useRef(false);

  const [formData, setFormData] = useState<FormData>({
    title: "",
    description: "",
    jobType: "",
    workLocationId: "",
    date: "",
    startTime: "",
    endTime: "",
    payRate: "",
    workersNeeded: "1",
    skillsRequired: "",
    physicalRequirements: "",
  });

  useEffect(() => {
    if (hasFetchedRef.current) return;
    hasFetchedRef.current = true;

    async function checkOnboardingAndFetchData() {
      try {
        // Check onboarding status first
        let onboardingResponse;
        try {
          onboardingResponse = await apiClient.getEmployerOnboardingStatus();
        } catch (err) {
          toast.error("Complete onboarding first", {
            description:
              "We couldn't confirm your onboarding status. Please complete all onboarding steps before posting shifts.",
            duration: 6000,
          });
          router.push("/dashboard/employer");
          return;
        }

        if (onboardingResponse.data?.all_tasks_complete !== true) {
          // Onboarding not complete - redirect with warning
          toast.error("Complete onboarding first", {
            description:
              "You must complete all onboarding steps before you can post shifts. Please add billing information and at least one work location.",
            duration: 6000,
          });
          router.push("/dashboard/employer");
          return;
        }

        // Onboarding complete - fetch work locations
        const response = await apiClient.getWorkLocations();
        if (response.data) {
          setWorkLocations(response.data.work_locations);
        }
      } catch (err) {
        console.error("Failed to fetch data:", err);
      } finally {
        setLoading(false);
      }
    }

    checkOnboardingAndFetchData();
  }, [router]);

  const updateFormData = (field: keyof FormData, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    setError(null);
  };

  const today = new Date();
  const todayLocalIsoDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(
    2,
    "0",
  )}-${String(today.getDate()).padStart(2, "0")}`;

  // Calculate duration in hours
  const calculateDurationHours = () => {
    if (!formData.date || !formData.startTime || !formData.endTime) return 0;

    const start = new Date(`${formData.date}T${formData.startTime}`);
    const end = new Date(`${formData.date}T${formData.endTime}`);

    // Handle overnight shifts
    if (end <= start) {
      end.setDate(end.getDate() + 1);
    }

    return (end.getTime() - start.getTime()) / (1000 * 60 * 60);
  };

  const durationHours = calculateDurationHours();

  // Calculate costs for receipt
  const calculateCostBreakdown = () => {
    const hourlyRate = parseFloat(formData.payRate) || 0;
    const workers = parseInt(formData.workersNeeded) || 0;
    const hours = durationHours;

    const workerPay = hourlyRate * hours * workers;
    const serviceFee = workerPay * SERVICE_FEE_RATE;
    const total = workerPay + serviceFee;

    return {
      hourlyRate,
      hours,
      workers,
      workerPay,
      serviceFee,
      total,
    };
  };

  const costBreakdown = calculateCostBreakdown();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);

    // Validation
    if (!formData.workLocationId) {
      setError("Please select a work location");
      setIsSubmitting(false);
      return;
    }

    if (!formData.jobType) {
      setError("Please select a job type");
      setIsSubmitting(false);
      return;
    }

    if (durationHours <= 0) {
      setError("End time must be after start time");
      setIsSubmitting(false);
      return;
    }

    try {
      // Build datetime strings
      const startDatetime = new Date(`${formData.date}T${formData.startTime}`).toISOString();
      let endDate = new Date(`${formData.date}T${formData.endTime}`);
      if (endDate <= new Date(`${formData.date}T${formData.startTime}`)) {
        endDate.setDate(endDate.getDate() + 1);
      }
      const endDatetime = endDate.toISOString();

      const result = await apiClient.createShift({
        work_location_id: parseInt(formData.workLocationId),
        title: formData.title,
        description: formData.description,
        job_type: formData.jobType,
        start_datetime: startDatetime,
        end_datetime: endDatetime,
        pay_rate_cents: Math.round(parseFloat(formData.payRate) * 100),
        slots_total: parseInt(formData.workersNeeded),
        skills_required: formData.skillsRequired || undefined,
        physical_requirements: formData.physicalRequirements || undefined,
      });

      if (result.error) {
        setError(result.error);
      } else if (result.data) {
        // Start recruiting immediately after creation
        await apiClient.startRecruitingShift(result.data.id);
        setCreatedTrackingCode(result.data.tracking_code);
        setSuccess(true);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create shift");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="p-4 lg:p-8 flex items-center justify-center min-h-[400px]">
        <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (success) {
    return (
      <div className="p-4 lg:p-8">
        <div className="max-w-2xl mx-auto">
          <Card>
            <CardContent className="p-8 text-center">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
                <CheckCircle2 className="w-8 h-8 text-green-600" />
              </div>
              <h2 className="text-2xl font-bold text-foreground mb-2">
                Shift Posted Successfully!
              </h2>
              <p className="text-muted-foreground mb-6">
                Your shift has been added to our recruiting pool. We will start
                reaching out to available workers immediately.
              </p>

              {createdTrackingCode && (
                <div className="bg-muted rounded-lg p-4 mb-6">
                  <p className="text-sm text-muted-foreground mb-1">Tracking Code</p>
                  <p className="text-2xl font-mono font-bold text-foreground">
                    {createdTrackingCode}
                  </p>
                  <p className="text-xs text-muted-foreground mt-2">
                    Use this code to reference this shift
                  </p>
                </div>
              )}

              <div className="bg-accent/10 border border-accent/20 rounded-lg p-4 mb-6">
                <h3 className="font-semibold text-foreground mb-2">What happens next?</h3>
                <ul className="text-sm text-muted-foreground space-y-2 text-left">
                  <li className="flex items-start gap-2">
                    <CheckCircle2 className="w-4 h-4 text-accent mt-0.5 shrink-0" />
                    We will send SMS notifications to qualified workers in your area
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle2 className="w-4 h-4 text-accent mt-0.5 shrink-0" />
                    Workers will confirm their availability via text
                  </li>
                  <li className="flex items-start gap-2">
                    <CheckCircle2 className="w-4 h-4 text-accent mt-0.5 shrink-0" />
                    You will be notified as positions are filled
                  </li>
                </ul>
              </div>

              <div className="flex gap-3">
                <Button
                  variant="outline"
                  className="flex-1"
                  onClick={() => {
                    setSuccess(false);
                    setCreatedTrackingCode(null);
                    setFormData({
                      title: "",
                      description: "",
                      jobType: "",
                      workLocationId: "",
                      date: "",
                      startTime: "",
                      endTime: "",
                      payRate: "",
                      workersNeeded: "1",
                      skillsRequired: "",
                      physicalRequirements: "",
                    });
                  }}
                >
                  Post Another Shift
                </Button>
                <Button asChild className="flex-1">
                  <Link href="/dashboard/employer">Back to Dashboard</Link>
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 lg:p-8">
      {/* Page Header */}
      <div className="mb-8">
        <Link
          href="/dashboard/employer"
          className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors mb-4"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to dashboard
        </Link>
        <h1 className="text-2xl font-bold text-foreground">Post a New Shift</h1>
        <p className="text-muted-foreground mt-1">
          Fill out the details below and we will find workers for you
        </p>
      </div>

      {error && (
        <div className="mb-6 p-4 rounded-lg bg-destructive/10 border border-destructive/20 text-destructive flex items-start gap-3">
          <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
          <p>{error}</p>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Form */}
        <div className="lg:col-span-2">
          <form id="shiftForm" onSubmit={handleSubmit}>
            <Card>
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <Calendar className="w-5 h-5" />
                  Shift Details
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Title */}
                <div>
                  <Label htmlFor="title">Shift Title</Label>
                  <Input
                    id="title"
                    placeholder="e.g., Warehouse Helper, Moving Crew, Event Staff"
                    className="mt-2 bg-card"
                    value={formData.title}
                    onChange={(e) => updateFormData("title", e.target.value)}
                    required
                  />
                </div>

                {/* Description */}
                <div>
                  <Label htmlFor="description">Description</Label>
                  <Textarea
                    id="description"
                    placeholder="Describe the work, responsibilities, and any specific requirements..."
                    className="mt-2 bg-card min-h-[100px]"
                    value={formData.description}
                    onChange={(e) => updateFormData("description", e.target.value)}
                    required
                  />
                </div>

                {/* Job Type & Location */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="jobType">Job Type</Label>
                    <Select
                      value={formData.jobType}
                      onValueChange={(value) => updateFormData("jobType", value)}
                    >
                      <SelectTrigger className="mt-2 bg-card">
                        <SelectValue placeholder="Select job type" />
                      </SelectTrigger>
                      <SelectContent>
                        {JOB_TYPES.map((type) => (
                          <SelectItem key={type.value} value={type.value}>
                            {type.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  <div>
                    <Label htmlFor="workLocation">Work Location</Label>
                    <Select
                      value={formData.workLocationId}
                      onValueChange={(value) => updateFormData("workLocationId", value)}
                    >
                      <SelectTrigger className="mt-2 bg-card">
                        <SelectValue placeholder="Select location" />
                      </SelectTrigger>
                      <SelectContent>
                        {workLocations.length === 0 ? (
                          <SelectItem value="none" disabled>
                            No locations available
                          </SelectItem>
                        ) : (
                          workLocations.map((location) => (
                            <SelectItem key={location.id} value={location.id.toString()}>
                              <div className="flex items-center gap-2">
                                <Building2 className="w-4 h-4" />
                                {location.display_name || location.name}
                              </div>
                            </SelectItem>
                          ))
                        )}
                      </SelectContent>
                    </Select>
                    {workLocations.length === 0 && (
                      <p className="text-xs text-muted-foreground mt-1">
                        No work locations found.{" "}
                        <Link href="/dashboard/employer/settings" className="text-accent hover:underline">
                          Add a location
                        </Link>
                      </p>
                    )}
                  </div>
                </div>

                {/* Date and Time */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <Label htmlFor="date">Date</Label>
                    <Input
                      id="date"
                      type="date"
                      className="mt-2 bg-card"
                      value={formData.date}
                      onChange={(e) => updateFormData("date", e.target.value)}
                      min={todayLocalIsoDate}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="startTime">Start Time</Label>
                    <Input
                      id="startTime"
                      type="time"
                      className="mt-2 bg-card"
                      value={formData.startTime}
                      onChange={(e) => updateFormData("startTime", e.target.value)}
                      required
                    />
                  </div>
                  <div>
                    <Label htmlFor="endTime">End Time</Label>
                    <Input
                      id="endTime"
                      type="time"
                      className="mt-2 bg-card"
                      value={formData.endTime}
                      onChange={(e) => updateFormData("endTime", e.target.value)}
                      required
                    />
                  </div>
                </div>

                {/* Pay Rate and Workers */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <Label htmlFor="payRate">Hourly Pay Rate ($)</Label>
                    <div className="relative mt-2">
                      <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                      <Input
                        id="payRate"
                        type="number"
                        step="0.50"
                        min="7.25"
                        placeholder="15.00"
                        className="pl-9 bg-card"
                        value={formData.payRate}
                        onChange={(e) => updateFormData("payRate", e.target.value)}
                        required
                      />
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      This is the rate workers will receive
                    </p>
                  </div>
                  <div>
                    <Label htmlFor="workersNeeded">Workers Needed</Label>
                    <div className="relative mt-2">
                      <Users className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                      <Input
                        id="workersNeeded"
                        type="number"
                        min="1"
                        max="50"
                        placeholder="1"
                        className="pl-9 bg-card"
                        value={formData.workersNeeded}
                        onChange={(e) => updateFormData("workersNeeded", e.target.value)}
                        required
                      />
                    </div>
                  </div>
                </div>

                {/* Optional Fields */}
                <div className="pt-4 border-t border-border">
                  <h3 className="font-medium text-foreground mb-4">Optional Details</h3>
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="skillsRequired">Skills Required</Label>
                      <Input
                        id="skillsRequired"
                        placeholder="e.g., Forklift certified, bilingual, experience with inventory systems"
                        className="mt-2 bg-card"
                        value={formData.skillsRequired}
                        onChange={(e) => updateFormData("skillsRequired", e.target.value)}
                      />
                    </div>
                    <div>
                      <Label htmlFor="physicalRequirements">Physical Requirements</Label>
                      <Input
                        id="physicalRequirements"
                        placeholder="e.g., Ability to lift 50 lbs, standing for extended periods"
                        className="mt-2 bg-card"
                        value={formData.physicalRequirements}
                        onChange={(e) => updateFormData("physicalRequirements", e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

          </form>
        </div>

        {/* Receipt / Cost Summary */}
        <div className="lg:col-span-1">
          <div className="sticky top-24">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <Receipt className="w-5 h-5" />
                  Order Summary
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Shift Summary */}
                {formData.title && (
                  <div className="pb-4 border-b border-border">
                    <h3 className="font-medium text-foreground">{formData.title}</h3>
                    {formData.jobType && (
                      <p className="text-sm text-muted-foreground mt-1">
                        {JOB_TYPES.find((t) => t.value === formData.jobType)?.label}
                      </p>
                    )}
                  </div>
                )}

                {/* Details */}
                <div className="space-y-3 text-sm">
                  <div className="flex items-center gap-2 text-muted-foreground">
                    <Clock className="w-4 h-4" />
                    <span>
                      {durationHours > 0
                        ? `${durationHours.toFixed(1)} hours`
                        : "—"}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-muted-foreground">
                    <Users className="w-4 h-4" />
                    <span>
                      {parseInt(formData.workersNeeded) > 0
                        ? `${formData.workersNeeded} worker${parseInt(formData.workersNeeded) !== 1 ? "s" : ""}`
                        : "—"}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-muted-foreground">
                    <DollarSign className="w-4 h-4" />
                    <span>
                      {parseFloat(formData.payRate) > 0
                        ? `$${parseFloat(formData.payRate).toFixed(2)}/hr`
                        : "—"}
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-muted-foreground">
                    <MapPin className="w-4 h-4" />
                    <span>
                      {formData.workLocationId
                        ? workLocations.find(
                            (l) => l.id.toString() === formData.workLocationId
                          )?.name || "Location selected"
                        : "—"}
                    </span>
                  </div>
                </div>

                {/* Cost Breakdown */}
                <div className="pt-4 border-t border-border space-y-3">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">
                      Worker Pay
                      {costBreakdown.hours > 0 && costBreakdown.hourlyRate > 0 && costBreakdown.workers > 0 && (
                        <span className="block text-xs">
                          ${costBreakdown.hourlyRate.toFixed(2)}/hr x{" "}
                          {costBreakdown.hours.toFixed(1)}hrs x{" "}
                          {costBreakdown.workers} worker
                          {costBreakdown.workers !== 1 ? "s" : ""}
                        </span>
                      )}
                    </span>
                    <span className="font-medium text-foreground">
                      ${costBreakdown.workerPay.toFixed(2)}
                    </span>
                  </div>

                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">
                      Service Fee
                      <span className="block text-xs">
                        20% platform fee
                      </span>
                    </span>
                    <span className="font-medium text-foreground">
                      ${costBreakdown.serviceFee.toFixed(2)}
                    </span>
                  </div>

                  <div className="pt-3 border-t border-border flex justify-between">
                    <span className="font-semibold text-foreground">Total</span>
                    <span className="text-xl font-bold text-foreground">
                      ${costBreakdown.total.toFixed(2)}
                    </span>
                  </div>
                </div>

                {/* Info */}
                <div className="pt-4 border-t border-border">
                  <p className="text-xs text-muted-foreground">
                    You will only be charged for hours actually worked. Final
                    invoice will be calculated based on timesheet approvals.
                  </p>
                </div>

                {/* Submit Button */}
                <Button
                  type="submit"
                  form="shiftForm"
                  size="lg"
                  className="w-full"
                  disabled={isSubmitting || workLocations.length === 0}
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Creating shift...
                    </>
                  ) : (
                    <>
                      <CheckCircle2 className="mr-2 h-4 w-4" />
                      Post Shift & Start Recruiting
                    </>
                  )}
                </Button>

                {workLocations.length === 0 && (
                  <p className="text-xs text-center text-muted-foreground mt-2">
                    You need to{" "}
                    <Link href="/dashboard/employer/settings" className="text-accent hover:underline">
                      add a work location
                    </Link>
                    {" "}before posting shifts.
                  </p>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}
