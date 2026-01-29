"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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
import { Switch } from "@/components/ui/switch";
import { Loader2 } from "lucide-react";
import { apiClient, type FeatureFlag } from "@/lib/api/client";
import { toast } from "sonner";

interface FeatureFlagModalProps {
  open: boolean;
  onClose: () => void;
  onSave: () => void;
  flag: FeatureFlag | null;
}

type ValueType = "boolean" | "string" | "number" | "json";

function getInitialValueType(flag: FeatureFlag | null): ValueType {
  if (!flag) return "boolean";
  if (flag.value_type === "boolean") return "boolean";
  if (flag.value_type === "string") return "string";
  if (flag.value_type === "number") return "number";
  return "json";
}

function getInitialBooleanValue(flag: FeatureFlag | null): boolean {
  if (!flag || flag.value_type !== "boolean") return false;
  return flag.value === true;
}

function getInitialStringValue(flag: FeatureFlag | null): string {
  if (!flag || flag.value_type !== "string") return "";
  return String(flag.value);
}

function getInitialNumberValue(flag: FeatureFlag | null): string {
  if (!flag || flag.value_type !== "number") return "";
  return String(flag.value);
}

function getInitialJsonValue(flag: FeatureFlag | null): string {
  if (!flag) return "";
  if (flag.value_type === "array" || flag.value_type === "object") {
    return JSON.stringify(flag.value, null, 2);
  }
  return "";
}

export function FeatureFlagModal({ open, onClose, onSave, flag }: FeatureFlagModalProps) {
  const isEditing = !!flag;

  const [key, setKey] = useState(() => flag?.key || "");
  const [description, setDescription] = useState(() => flag?.description || "");
  const [valueType, setValueType] = useState<ValueType>(() => getInitialValueType(flag));
  const [booleanValue, setBooleanValue] = useState(() => getInitialBooleanValue(flag));
  const [stringValue, setStringValue] = useState(() => getInitialStringValue(flag));
  const [numberValue, setNumberValue] = useState(() => getInitialNumberValue(flag));
  const [jsonValue, setJsonValue] = useState(() => getInitialJsonValue(flag));
  const [jsonError, setJsonError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const handleOpenChange = (isOpen: boolean) => {
    if (isOpen) {
      // Reset form state when opening
      setKey(flag?.key || "");
      setDescription(flag?.description || "");
      setValueType(getInitialValueType(flag));
      setBooleanValue(getInitialBooleanValue(flag));
      setStringValue(getInitialStringValue(flag));
      setNumberValue(getInitialNumberValue(flag));
      setJsonValue(getInitialJsonValue(flag));
      setJsonError(null);
      setSaving(false);
    } else {
      onClose();
    }
  };

  const getValue = (): boolean | string | number | Record<string, unknown> | unknown[] => {
    switch (valueType) {
      case "boolean":
        return booleanValue;
      case "string":
        return stringValue;
      case "number":
        const parsed = parseFloat(numberValue);
        return Number.isNaN(parsed) ? 0 : parsed;
      case "json":
        try {
          return JSON.parse(jsonValue) as Record<string, unknown> | unknown[];
        } catch {
          return {};
        }
    }
  };

  const validateKey = (value: string): boolean => {
    return /^[a-z][a-z0-9_]*$/.test(value);
  };

  const validateJson = (value: string): boolean => {
    if (valueType !== "json") return true;
    try {
      JSON.parse(value);
      setJsonError(null);
      return true;
    } catch {
      setJsonError("Invalid JSON format");
      return false;
    }
  };

  const handleSave = async () => {
    if (!key) {
      toast.error("Key is required");
      return;
    }

    if (!validateKey(key)) {
      toast.error("Key must be lowercase snake_case starting with a letter");
      return;
    }

    if (valueType === "json" && !validateJson(jsonValue)) {
      toast.error("Invalid JSON format");
      return;
    }

    setSaving(true);

    try {
      const value = getValue();

      if (isEditing) {
        const response = await apiClient.updateFeatureFlag(flag.id, {
          value,
          description: description || undefined,
        });

        if (response.error) {
          toast.error(`Failed to update flag: ${response.error}`);
          return;
        }

        toast.success(`Flag "${key}" updated`);
      } else {
        const response = await apiClient.createFeatureFlag({
          key,
          value,
          description: description || undefined,
        });

        if (response.error) {
          toast.error(`Failed to create flag: ${response.error}`);
          return;
        }

        toast.success(`Flag "${key}" created`);
      }

      onSave();
    } catch (error) {
      console.error("Feature flag save error:", error);
      toast.error(
        error instanceof Error ? error.message : "An unexpected error occurred"
      );
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>{isEditing ? "Edit Feature Flag" : "Create Feature Flag"}</DialogTitle>
          <DialogDescription>
            {isEditing
              ? "Update the feature flag configuration."
              : "Create a new feature flag to control application behavior."}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="key">Key</Label>
            <Input
              id="key"
              placeholder="my_feature_flag"
              value={key}
              onChange={(e) => {
                const cleaned = e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "_");
                setKey(/^\d/.test(cleaned) ? "_" + cleaned : cleaned);
              }}
              disabled={isEditing}
              className="font-mono"
            />
            <p className="text-xs text-muted-foreground">
              Lowercase snake_case, starting with a letter (e.g., worker_login_enabled)
            </p>
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <Textarea
              id="description"
              placeholder="Describe what this flag controls..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="valueType">Value Type</Label>
            <Select
              value={valueType}
              onValueChange={(v) => setValueType(v as ValueType)}
              disabled={isEditing}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="boolean">Boolean (on/off)</SelectItem>
                <SelectItem value="string">String</SelectItem>
                <SelectItem value="number">Number</SelectItem>
                <SelectItem value="json">JSON (array/object)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label>Value</Label>
            {valueType === "boolean" && (
              <div className="flex items-center gap-3 py-2">
                <Switch
                  checked={booleanValue}
                  onCheckedChange={setBooleanValue}
                />
                <span className="text-sm text-muted-foreground">
                  {booleanValue ? "Enabled" : "Disabled"}
                </span>
              </div>
            )}

            {valueType === "string" && (
              <Input
                placeholder="Enter string value"
                value={stringValue}
                onChange={(e) => setStringValue(e.target.value)}
              />
            )}

            {valueType === "number" && (
              <Input
                type="number"
                placeholder="Enter number value"
                value={numberValue}
                onChange={(e) => setNumberValue(e.target.value)}
              />
            )}

            {valueType === "json" && (
              <div className="space-y-1">
                <Textarea
                  placeholder='{"key": "value"}'
                  value={jsonValue}
                  onChange={(e) => {
                    setJsonValue(e.target.value);
                    validateJson(e.target.value);
                  }}
                  rows={5}
                  className="font-mono text-sm"
                />
                {jsonError && <p className="text-xs text-destructive">{jsonError}</p>}
              </div>
            )}
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose} disabled={saving}>
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            {isEditing ? "Save Changes" : "Create Flag"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
