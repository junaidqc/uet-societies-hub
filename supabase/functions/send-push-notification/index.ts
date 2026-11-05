// ============================================================================
// Edge Function: send-push-notification
// Project: UET Societies Hub
// Description: FCM HTTP v1 Push Notification Dispatcher (Phase 7).
//              Authenticates using Google Service Account OAuth2 JWT flow.
//              Handles triggers: new_post, new_hiring, deadline_reminder,
//              application_status, group_message.
//              Respects user mute preferences from notification_preferences.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ServiceAccountKey {
  project_id: string;
  client_email: string;
  private_key: string;
}

// Helper: Base64 URL encoding
function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

// Convert PEM PKCS#8 private key string to ArrayBuffer for Web Crypto
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleanPem = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/[\r\n\s]/g, "");
  const binary = atob(cleanPem);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Exchange Google Service Account credentials for an OAuth2 Access Token
async function getGoogleOAuth2Token(serviceAccount: ServiceAccountKey): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const keyBuffer = pemToArrayBuffer(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  // Request access token from Google
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Google OAuth2 Token Exchange failed: ${errorBody}`);
  }

  const tokenData = await response.json();
  return tokenData.access_token;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const body = await req.json();
    const {
      trigger, // 'new_post' | 'new_hiring' | 'deadline_reminder' | 'application_status' | 'group_message'
      society_id,
      group_id,
      title,
      message,
      data = {},
      target_user_ids: directTargetUserIds,
    } = body;

    if (!trigger || !title || !message) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: trigger, title, message" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let recipientUserIds: string[] = [];

    // 1. Resolve Target User IDs based on Trigger
    if (directTargetUserIds && Array.isArray(directTargetUserIds) && directTargetUserIds.length > 0) {
      recipientUserIds = directTargetUserIds;
    } else if (trigger === "new_post" || trigger === "new_hiring") {
      if (!society_id) throw new Error("society_id required for new_post or new_hiring");
      // Get all followers of the society
      const { data: follows, error: fErr } = await supabase
        .from("follows")
        .select("user_id")
        .eq("society_id", society_id);
      if (fErr) throw fErr;
      recipientUserIds = (follows || []).map((f: { user_id: string }) => f.user_id);
    } else if (trigger === "group_message") {
      if (!group_id) throw new Error("group_id required for group_message");
      const senderId = data.sender_id;
      // Get all members of group except sender
      const { data: members, error: mErr } = await supabase
        .from("group_members")
        .select("user_id")
        .eq("group_id", group_id);
      if (mErr) throw mErr;
      recipientUserIds = (members || [])
        .map((m: { user_id: string }) => m.user_id)
        .filter((uid: string) => uid !== senderId);
    }

    if (recipientUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No recipients to notify", count: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Filter out users who have MUTED this society or group (notification_preferences)
    let filteredRecipientIds = recipientUserIds;
    if (society_id || group_id) {
      let prefQuery = supabase
        .from("notification_preferences")
        .select("user_id")
        .eq("is_muted", true)
        .in("user_id", recipientUserIds);

      if (society_id && group_id) {
        prefQuery = prefQuery.or(`society_id.eq.${society_id},group_id.eq.${group_id}`);
      } else if (society_id) {
        prefQuery = prefQuery.eq("society_id", society_id);
      } else if (group_id) {
        prefQuery = prefQuery.eq("group_id", group_id);
      }

      const { data: mutedRows, error: prefErr } = await prefQuery;
      if (!prefErr && mutedRows && mutedRows.length > 0) {
        const mutedSet = new Set(mutedRows.map((r: { user_id: string }) => r.user_id));
        filteredRecipientIds = recipientUserIds.filter((uid) => !mutedSet.has(uid));
      }
    }

    if (filteredRecipientIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "All recipients have muted this channel", count: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Insert In-App Notifications in batches
    const inAppRows = filteredRecipientIds.map((uid) => ({
      user_id: uid,
      title: title,
      body: message,
      data: { ...data, trigger },
    }));

    // Batch insert into public.notifications
    for (let i = 0; i < inAppRows.length; i += 500) {
      const chunk = inAppRows.slice(i, i + 500);
      const { error: insErr } = await supabase.from("notifications").insert(chunk);
      if (insErr) {
        console.error("In-app notification insert error:", insErr.message);
      }
    }

    // 4. Send FCM Push Notification via HTTP v1 API
    let fcmSentCount = 0;
    let fcmFailCount = 0;

    if (serviceAccountJson) {
      try {
        const serviceAccount: ServiceAccountKey = JSON.parse(serviceAccountJson);
        const accessToken = await getGoogleOAuth2Token(serviceAccount);
        const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

        // Fetch valid device tokens for filtered recipients
        const { data: tokens, error: tokenErr } = await supabase
          .from("device_tokens")
          .select("token, user_id")
          .in("user_id", filteredRecipientIds);

        if (!tokenErr && tokens && tokens.length > 0) {
          for (const item of tokens) {
            const fcmPayload = {
              message: {
                token: item.token,
                notification: {
                  title: title,
                  body: message,
                },
                data: Object.fromEntries(
                  Object.entries({ ...data, trigger }).map(([k, v]) => [k, String(v)])
                ),
                android: {
                  priority: "HIGH",
                  notification: {
                    sound: "default",
                    channel_id: "uet_societies_channel",
                  },
                },
              },
            };

            const fcmRes = await fetch(fcmEndpoint, {
              method: "POST",
              headers: {
                Authorization: `Bearer ${accessToken}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify(fcmPayload),
            });

            if (fcmRes.ok) {
              fcmSentCount++;
            } else {
              fcmFailCount++;
              const fcmErrorText = await fcmRes.text();
              console.warn(`FCM send failed for user ${item.user_id}:`, fcmErrorText);
            }
          }
        }
      } catch (fcmInitErr) {
        console.error("FCM dispatch error:", fcmInitErr);
      }
    } else {
      console.log("FIREBASE_SERVICE_ACCOUNT_JSON not set. In-app notifications stored successfully.");
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipients_count: filteredRecipientIds.length,
        fcm_sent: fcmSentCount,
        fcm_failed: fcmFailCount,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error("send-push-notification error:", errorMsg);
    return new Response(
      JSON.stringify({ success: false, error: errorMsg }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
