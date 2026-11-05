// ============================================================================
// Edge Function: cleanup-old-data
// Project: UET Societies Hub
// Description: Automated data retention cleanup (Phase 5b).
//              Purges 30-day-old group chat messages, storage attachments,
//              old notifications, and stale device tokens.
// Security: Requires x-cron-secret header matching CRON_SECRET environment secret.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Authenticate via CRON_SECRET header
    const cronSecretHeader = req.headers.get("x-cron-secret");
    const expectedSecret = Deno.env.get("CRON_SECRET");

    if (!expectedSecret || cronSecretHeader !== expectedSecret) {
      console.warn("Unauthorized cleanup attempt: invalid or missing x-cron-secret");
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Initialize Supabase Admin Client using service-role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in environment");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false }
    });

    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const startTime = Date.now();
    const TIME_LIMIT_MS = 50000; // 50s execution limit to avoid edge function timeout

    let totalMessagesDeleted = 0;
    let totalFilesDeleted = 0;

    // 3. Batch delete group messages older than 30 days (batches of 500)
    while (Date.now() - startTime < TIME_LIMIT_MS) {
      const { data: messages, error: selectErr } = await supabase
        .from("group_messages")
        .select("id, attachment_path")
        .lt("created_at", thirtyDaysAgo)
        .order("created_at", { ascending: true })
        .limit(500);

      if (selectErr) {
        throw new Error(`Error fetching old messages: ${selectErr.message}`);
      }

      if (!messages || messages.length === 0) {
        break; // All old messages cleaned up
      }

      // Collect attachment paths for storage removal (Storage API only; never raw SQL delete on storage.objects)
      const attachmentPaths = messages
        .map((m: { id: string; attachment_path: string | null }) => m.attachment_path)
        .filter((p: string | null): p is string => Boolean(p && p.trim().length > 0));

      if (attachmentPaths.length > 0) {
        // Chunk storage remove to 100 files per call
        for (let i = 0; i < attachmentPaths.length; i += 100) {
          const chunk = attachmentPaths.slice(i, i + 100);
          const { error: storageErr } = await supabase.storage
            .from("chat-attachments")
            .remove(chunk);

          if (storageErr) {
            console.error(`Storage file deletion error: ${storageErr.message}`);
          } else {
            totalFilesDeleted += chunk.length;
          }
        }
      }

      // Delete message rows from database
      const messageIds = messages.map((m: { id: string }) => m.id);
      const { error: deleteErr } = await supabase
        .from("group_messages")
        .delete()
        .in("id", messageIds);

      if (deleteErr) {
        throw new Error(`Error deleting message rows: ${deleteErr.message}`);
      }

      totalMessagesDeleted += messageIds.length;
    }

    // 4. Delete notifications older than 30 days
    const { data: deletedNotifs, error: notifErr } = await supabase
      .from("notifications")
      .delete()
      .lt("created_at", thirtyDaysAgo)
      .select("id");

    if (notifErr) {
      console.error(`Error deleting old notifications: ${notifErr.message}`);
    }
    const notificationsDeleted = deletedNotifs ? deletedNotifs.length : 0;

    // 5. Delete stale device tokens (> 30 days since last update)
    const { data: deletedTokens, error: tokenErr } = await supabase
      .from("device_tokens")
      .delete()
      .lt("updated_at", thirtyDaysAgo)
      .select("id");

    if (tokenErr) {
      console.error(`Error deleting stale device tokens: ${tokenErr.message}`);
    }
    const tokensDeleted = deletedTokens ? deletedTokens.length : 0;

    // 6. Delete completed polls and tasks older than 30 days (if created_at < 30 days ago)
    // Note: Completed polls/tasks are message records and have already been processed in step 3.

    // 7. Write execution summary to audit_log (NO PII, NO message content, counts only)
    await supabase.from("audit_log").insert({
      actor_id: null,
      action: "RETENTION_CLEANUP",
      entity_type: "system",
      entity_id: "cleanup-old-data",
      metadata: {
        messages_deleted: totalMessagesDeleted,
        files_deleted: totalFilesDeleted,
        notifications_deleted: notificationsDeleted,
        device_tokens_deleted: tokensDeleted,
        executed_at: new Date().toISOString(),
        duration_ms: Date.now() - startTime
      }
    });

    // 8. Return response
    return new Response(
      JSON.stringify({
        success: true,
        summary: {
          messages_deleted: totalMessagesDeleted,
          files_deleted: totalFilesDeleted,
          notifications_deleted: notificationsDeleted,
          device_tokens_deleted: tokensDeleted,
          duration_ms: Date.now() - startTime
        }
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("Retention cleanup error:", message);
    return new Response(
      JSON.stringify({ success: false, error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      }
    );
  }
});
