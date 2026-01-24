const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001";

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: Record<string, unknown>;
  headers?: Record<string, string>;
}

interface ApiResponse<T> {
  data: T | null;
  error: string | null;
  status: number;
}

class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    // Restore token from localStorage if available
    if (typeof window !== "undefined") {
      this.token = localStorage.getItem("authToken");
    }
  }

  setToken(token: string | null) {
    this.token = token;
    if (typeof window !== "undefined") {
      if (token) {
        localStorage.setItem("authToken", token);
      } else {
        localStorage.removeItem("authToken");
      }
    }
  }

  getToken(): string | null {
    return this.token;
  }

  async request<T>(
    endpoint: string,
    options: RequestOptions = {}
  ): Promise<ApiResponse<T>> {
    const { method = "GET", body, headers = {} } = options;

    const requestHeaders: Record<string, string> = {
      "Content-Type": "application/json",
      ...headers,
    };

    if (this.token) {
      requestHeaders["Authorization"] = `Bearer ${this.token}`;
    }

    try {
      const response = await fetch(`${this.baseUrl}${endpoint}`, {
        method,
        headers: requestHeaders,
        body: body ? JSON.stringify(body) : undefined,
      });

      // Extract JWT token from Authorization header on login/register
      const authHeader = response.headers.get("Authorization");
      if (authHeader && authHeader.startsWith("Bearer ")) {
        this.setToken(authHeader.replace("Bearer ", ""));
      }

      const data = await response.json();

      if (!response.ok) {
        return {
          data: null,
          error: data.error || data.errors?.join(", ") || "An error occurred",
          status: response.status,
        };
      }

      return {
        data,
        error: null,
        status: response.status,
      };
    } catch (error) {
      return {
        data: null,
        error: error instanceof Error ? error.message : "Network error",
        status: 0,
      };
    }
  }

  // Auth endpoints
  async register(
    email: string,
    password: string,
    passwordConfirmation: string,
    role: "worker" | "employer",
    companyAttributes?: Record<string, unknown>,
    employerProfileAttributes?: Record<string, unknown>
  ) {
    const userBody: Record<string, unknown> = {
      email,
      password,
      password_confirmation: passwordConfirmation,
      role,
    };

    // Add nested attributes if provided
    if (companyAttributes) {
      userBody.company_attributes = companyAttributes;
    }
    if (employerProfileAttributes) {
      userBody.employer_profile_attributes = employerProfileAttributes;
    }

    return this.request<{ message: string; user: User }>("/api/v1/auth/register", {
      method: "POST",
      body: {
        user: userBody,
      },
    });
  }

  async login(email: string, password: string) {
    return this.request<{ message: string; user: User }>("/api/v1/auth/login", {
      method: "POST",
      body: {
        user: {
          email,
          password,
        },
      },
    });
  }

  async logout() {
    const response = await this.request<{ message: string }>("/api/v1/auth/logout", {
      method: "DELETE",
    });
    this.setToken(null);
    return response;
  }

  async getCurrentUser() {
    return this.request<{ user: User }>("/api/v1/auth/me");
  }

  async updateCurrentUser(email: string) {
    return this.request<{ message: string; user: User }>("/api/v1/auth/me", {
      method: "PATCH",
      body: {
        user: {
          email,
        },
      },
    });
  }

  // Shift endpoints
  async getShifts(params?: {
    status?: string;
    job_type?: string;
    company_id?: number;
    start_date?: string;
    end_date?: string;
    page?: number;
    per_page?: number;
    direction?: "asc" | "desc";
  }) {
    const queryString = params
      ? "?" +
        Object.entries(params)
          .filter(([_, v]) => v !== undefined)
          .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
          .join("&")
      : "";
    return this.request<{
      shifts: Shift[];
      meta: { total: number; page?: number; per_page?: number; total_pages?: number };
    }>(
      `/api/v1/shifts${queryString}`
    );
  }

  async getShift(id: number) {
    return this.request<Shift>(`/api/v1/shifts/${id}`);
  }

  async createShift(shiftData: CreateShiftData) {
    return this.request<Shift>("/api/v1/shifts", {
      method: "POST",
      body: { shift: shiftData },
    });
  }

  async updateShift(id: number, shiftData: Partial<CreateShiftData>) {
    return this.request<Shift>(`/api/v1/shifts/${id}`, {
      method: "PATCH",
      body: { shift: shiftData },
    });
  }

  async deleteShift(id: number) {
    return this.request<void>(`/api/v1/shifts/${id}`, {
      method: "DELETE",
    });
  }

  async startRecruitingShift(id: number) {
    return this.request<Shift>(`/api/v1/shifts/${id}/start_recruiting`, {
      method: "POST",
    });
  }

  async cancelShift(id: number, reason?: string) {
    return this.request<Shift>(`/api/v1/shifts/${id}/cancel`, {
      method: "POST",
      body: { reason },
    });
  }

  // Shift Assignment endpoints
  async getShiftAssignments(params?: {
    status?: string;
    shift_id?: number;
    shift_ids?: number[];
    start_date?: string;
    end_date?: string;
  }) {
    const queryString = params
      ? "?" +
        Object.entries(params)
          .filter(([_, v]) => v !== undefined)
          .map(([k, v]) => {
            if (Array.isArray(v)) {
              return `${k}=${encodeURIComponent(v.join(","))}`;
            }
            return `${k}=${encodeURIComponent(v)}`;
          })
          .join("&")
      : "";
    return this.request<{
      shift_assignments: ShiftAssignment[];
      meta: { total: number };
    }>(`/api/v1/shift_assignments${queryString}`);
  }

  async getShiftAssignment(id: number) {
    return this.request<ShiftAssignment>(`/api/v1/shift_assignments/${id}`);
  }

  async acceptShiftAssignment(id: number, method: string = "app") {
    return this.request<ShiftAssignment>(
      `/api/v1/shift_assignments/${id}/accept`,
      {
        method: "POST",
        body: { method },
      }
    );
  }

  async declineShiftAssignment(id: number, reason?: string, method: string = "app") {
    return this.request<ShiftAssignment>(
      `/api/v1/shift_assignments/${id}/decline`,
      {
        method: "POST",
        body: { reason, method },
      }
    );
  }

  async approveTimesheet(id: number) {
    return this.request<ShiftAssignment>(
      `/api/v1/shift_assignments/${id}/approve_timesheet`,
      {
        method: "POST",
      }
    );
  }

  // Profile endpoints
  async getWorkerProfile() {
    return this.request<WorkerProfile>("/api/v1/workers/me");
  }

  async createWorkerProfile(profileData: CreateWorkerProfileData) {
    return this.request<WorkerProfile>("/api/v1/workers", {
      method: "POST",
      body: { worker_profile: profileData },
    });
  }

  async updateWorkerProfile(profileData: Partial<CreateWorkerProfileData>) {
    return this.request<WorkerProfile>("/api/v1/workers/me", {
      method: "PATCH",
      body: { worker_profile: profileData },
    });
  }

  async getEmployerProfile() {
    return this.request<EmployerProfile>("/api/v1/employers/me");
  }

  // Admin worker endpoints
  async getWorkers(params?: { page?: number; per_page?: number; status?: string }) {
    const queryString = params
      ? "?" +
        Object.entries(params)
          .filter(([_, v]) => v !== undefined)
          .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
          .join("&")
      : "";
    return this.request<{
      workers: WorkerSummary[];
      meta: { total: number; page?: number; per_page?: number; total_pages?: number };
    }>(`/api/v1/workers${queryString}`);
  }

  async createEmployerProfile(profileData: CreateEmployerProfileData) {
    return this.request<EmployerProfile>("/api/v1/employers", {
      method: "POST",
      body: { employer_profile: profileData },
    });
  }

  async updateEmployerProfile(profileData: Partial<CreateEmployerProfileData>) {
    return this.request<EmployerProfile>("/api/v1/employers/me", {
      method: "PATCH",
      body: { employer_profile: profileData },
    });
  }

  // Company endpoints
  async getCompanies(params?: { page?: number; per_page?: number }) {
    const queryString = params
      ? "?" +
        Object.entries(params)
          .filter(([_, v]) => v !== undefined)
          .map(([k, v]) => `${k}=${encodeURIComponent(v)}`)
          .join("&")
      : "";
    return this.request<{
      companies: Company[];
      meta: { total: number; page?: number; per_page?: number; total_pages?: number };
    }>(`/api/v1/companies${queryString}`);
  }

  async getCompany(id: number) {
    return this.request<Company>(`/api/v1/companies/${id}`);
  }

  async createCompany(companyData: CreateCompanyData) {
    return this.request<Company>("/api/v1/companies", {
      method: "POST",
      body: { company: companyData },
    });
  }

  // Work Location endpoints
  async getWorkLocations(companyId?: number) {
    const queryString = companyId ? `?company_id=${companyId}` : "";
    return this.request<{
      work_locations: WorkLocation[];
      meta: { total: number };
    }>(`/api/v1/work_locations${queryString}`);
  }

  async createWorkLocation(locationData: CreateWorkLocationData) {
    return this.request<WorkLocation>("/api/v1/work_locations", {
      method: "POST",
      body: { work_location: locationData },
    });
  }

  // Activity endpoints
  async getActivities(limit?: number) {
    const queryString = limit ? `?limit=${limit}` : "";
    return this.request<{ activities: Activity[]; meta: { total: number } }>(
      `/api/v1/activities${queryString}`
    );
  }
}

export interface User {
  id: number;
  email: string;
  role: "worker" | "employer" | "admin";
  created_at: string;
  updated_at: string;
}

export interface Shift {
  id: number;
  tracking_code: string;
  company: {
    id: number;
    name: string;
  };
  work_location: {
    id: number;
    name: string;
    address: string;
    city: string;
    state: string;
    zip_code: string;
    latitude: number | null;
    longitude: number | null;
    arrival_instructions: string | null;
    parking_notes: string | null;
  };
  created_by: {
    id: number;
    name: string;
  };
  title: string;
  description: string;
  job_type: string;
  schedule: {
    start_datetime: string;
    end_datetime: string;
    duration_hours: number;
    formatted_range: string;
  };
  pay: {
    rate_cents: number;
    hourly_rate: number;
    formatted_rate: string;
    estimated_total: number;
    formatted_estimated: string;
  };
  capacity: {
    slots_total: number;
    slots_filled: number;
    slots_available: number;
    min_workers_needed: number;
    fully_filled: boolean;
  };
  status: string;
  status_timestamps: {
    posted_at: string | null;
    recruiting_started_at: string | null;
    filled_at: string | null;
    completed_at: string | null;
    cancelled_at: string | null;
  };
  cancellation_reason: string | null;
  requirements: {
    skills_required: string | null;
    physical_requirements: string | null;
  };
  created_at: string;
  updated_at: string;
}

export interface ShiftAssignment {
  id: number;
  shift: {
    id: number;
    title: string;
    job_type: string;
    start_datetime: string;
    end_datetime: string;
    pay_rate_cents: number;
    formatted_pay_rate: string;
    status: string;
  };
  worker: {
    id: number;
    full_name: string;
    phone: string;
    average_rating: number | null;
    reliability_score: number | null;
  };
  assignment_metadata: {
    assigned_at: string;
    assigned_by: string;
    algorithm_score: number | null;
    distance_miles: number | null;
  };
  recruiting_timeline: {
    sms_sent_at: string | null;
    sms_delivered_at: string | null;
    response_received_at: string | null;
    response_method: string | null;
    response_value: string | null;
    response_time_minutes: number | null;
    decline_reason: string | null;
  };
  status: string;
  status_timestamps: {
    accepted_at: string | null;
    confirmed_at: string | null;
    cancelled_at: string | null;
    cancellation_reason: string | null;
    cancelled_by: string | null;
  };
  timesheet: {
    checked_in_at: string | null;
    checked_out_at: string | null;
    actual_start_time: string | null;
    actual_end_time: string | null;
    actual_hours_worked: number | null;
    timesheet_approved_at: string | null;
    calculated_pay_cents: number;
    formatted_pay: string;
  };
  performance: {
    worker_rating: number | null;
    employer_rating: number | null;
    worker_feedback: string | null;
    employer_feedback: string | null;
    no_show: boolean;
    completed_successfully: boolean | null;
  };
  created_at: string;
  updated_at: string;
}

export interface WorkerProfile {
  id: number;
  user_id: number;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string;
  address: {
    line_1: string;
    line_2: string | null;
    city: string;
    state: string;
    zip_code: string;
    latitude: number | null;
    longitude: number | null;
  };
  onboarding_completed: boolean;
  over_18_confirmed: boolean;
  terms_accepted_at: string | null;
  sms_consent_given_at: string | null;
  performance: {
    total_shifts_completed: number;
    total_shifts_assigned: number;
    no_show_count: number;
    average_rating: number | null;
    reliability_score: number | null;
    attendance_rate: number;
    no_show_rate: number;
  };
  payment_info: {
    preferred_payment_method: string;
    bank_account_last_4: string | null;
  };
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface WorkerSummary {
  id: number;
  user_id: number;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string;
  onboarding_completed: boolean;
  is_active: boolean;
  status: "active" | "onboarding" | "inactive";
  total_shifts_completed: number;
  last_shift: {
    date: string | null;
    role: string | null;
    job_type: string | null;
    company_name: string | null;
  } | null;
}

export interface EmployerProfile {
  id: number;
  user_id: number;
  company_id: number;
  company: {
    id: number;
    name: string;
    industry: string | null;
    is_active: boolean;
  } | null;
  first_name: string;
  last_name: string;
  full_name: string;
  title: string | null;
  phone: string;
  onboarding_completed: boolean;
  terms_accepted_at: string | null;
  msa_accepted_at: string | null;
  permissions: {
    can_post_shifts: boolean;
    can_approve_timesheets: boolean;
    is_billing_contact: boolean;
  };
  created_at: string;
  updated_at: string;
}

export interface Company {
  id: number;
  name: string;
  industry: string | null;
  billing_info: {
    email: string | null;
    phone: string | null;
    address: string;
  };
  tax_info: {
    tax_id: string | null;
    payment_terms: string | null;
  };
  is_active: boolean;
  shift_summary?: {
    total: number;
    active: number;
    by_status: {
      posted: number;
      recruiting: number;
      in_progress: number;
    };
  };
  last_shift_requested_at?: string | null;
  created_at: string;
  updated_at: string;
}

export interface WorkLocation {
  id: number;
  company_id: number;
  name: string;
  address: {
    line_1: string;
    line_2: string | null;
    city: string;
    state: string;
    zip_code: string;
    full_address: string;
  };
  coordinates: {
    latitude: number | null;
    longitude: number | null;
  };
  instructions: {
    arrival: string | null;
    parking: string | null;
  };
  is_active: boolean;
  display_name: string;
  created_at: string;
  updated_at: string;
}

// Create types
export interface CreateShiftData {
  work_location_id: number;
  title: string;
  description: string;
  job_type: string;
  start_datetime: string;
  end_datetime: string;
  pay_rate_cents: number;
  slots_total: number;
  min_workers_needed?: number;
  skills_required?: string;
  physical_requirements?: string;
}

export interface CreateWorkerProfileData {
  first_name: string;
  last_name: string;
  phone: string;
  address_line_1: string;
  address_line_2?: string;
  city: string;
  state: string;
  zip_code: string;
  latitude?: number;
  longitude?: number;
  over_18_confirmed: boolean;
  terms_accepted_at?: string;
  sms_consent_given_at?: string;
  ssn_encrypted?: string;
  preferred_payment_method?: string;
  bank_account_last_4?: string;
  preferred_job_types?: string[];
  availabilities?: Array<{
    day_of_week: number;
    start_time: string;
    end_time: string;
  }>;
}

export interface CreateEmployerProfileData {
  company_id: number;
  first_name: string;
  last_name: string;
  title?: string;
  phone: string;
  terms_accepted_at?: string;
  msa_accepted_at?: string;
  can_post_shifts?: boolean;
  can_approve_timesheets?: boolean;
  is_billing_contact?: boolean;
}

export interface CreateCompanyData {
  name: string;
  industry?: string;
  billing_email?: string;
  billing_phone?: string;
  billing_address_line_1?: string;
  billing_address_line_2?: string;
  billing_city?: string;
  billing_state?: string;
  billing_zip_code?: string;
  tax_id?: string;
  payment_terms?: string;
}

export interface CreateWorkLocationData {
  name: string;
  address_line_1: string;
  address_line_2?: string;
  city: string;
  state: string;
  zip_code: string;
  latitude?: number;
  longitude?: number;
  arrival_instructions?: string;
  parking_notes?: string;
}

export interface Activity {
  id: string;
  type: string;
  icon: string;
  title: string;
  description: string;
  timestamp: string;
  status: "pending" | "success" | "error" | "info" | "neutral";
  metadata?: Record<string, unknown>;
}

export const apiClient = new ApiClient(API_URL);
