// ================================================================
// Edge Function: notify-log-size
// Percorso su Supabase: supabase/functions/notify-log-size/index.ts
//
// Invia una email all'admin quando il log supera 50MB.
// Usa Resend (resend.com) — piano gratuito: 3.000 email/mese
// ================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? ""
const ADMIN_EMAIL    = Deno.env.get("ADMIN_EMAIL")    ?? ""   // es. para@4dsistemi.it
const FROM_EMAIL     = Deno.env.get("FROM_EMAIL")     ?? "noreply@4dsistemi.it"

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 })
  }

  let body: { size_mb: number; size_bytes: number; threshold: string }
  try {
    body = await req.json()
  } catch {
    return new Response("Invalid JSON", { status: 400 })
  }

  const { size_mb, threshold } = body

  // Componi l'email
  const html = `
    <div style="font-family: -apple-system, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px;">
      <div style="background: #C0392B; color: white; padding: 16px 24px; border-radius: 8px 8px 0 0;">
        <h2 style="margin:0; font-size:18px;">⚠️ Audit Log — Soglia raggiunta</h2>
      </div>
      <div style="background: #fff; border: 1px solid #e8d8d6; border-top: none; padding: 24px; border-radius: 0 0 8px 8px;">
        <p style="color:#333; font-size:15px; margin-top:0">
          Il registro delle modifiche di <strong>4D Sistemi Informatici</strong> ha superato la soglia configurata.
        </p>
        <table style="width:100%; background:#fafafa; border-radius:6px; padding:16px; border-collapse:collapse;">
          <tr>
            <td style="color:#666; font-size:13px; padding:6px 0;">Dimensione attuale</td>
            <td style="font-weight:600; font-size:15px; text-align:right; color:#C0392B">${size_mb} MB</td>
          </tr>
          <tr>
            <td style="color:#666; font-size:13px; padding:6px 0;">Soglia configurata</td>
            <td style="font-size:13px; text-align:right; color:#333">${threshold}</td>
          </tr>
          <tr>
            <td style="color:#666; font-size:13px; padding:6px 0;">Data rilevamento</td>
            <td style="font-size:13px; text-align:right; color:#333">${new Date().toLocaleString("it-IT")}</td>
          </tr>
        </table>
        <div style="margin-top:20px; padding:12px 16px; background:#FDF6F5; border-left:3px solid #C0392B; border-radius:4px; font-size:13px; color:#666;">
          <strong>Cosa fare:</strong> accedi al Pannello Admin → scheda "Log attività" per consultare e 
          valutare se archiviare o esportare le voci più vecchie.
        </div>
        <p style="font-size:11px; color:#999; margin-top:24px; margin-bottom:0;">
          Questo è un messaggio automatico generato da 4D Matrice Servizi.<br>
          Non rispondere a questa email.
        </p>
      </div>
    </div>
  `

  // Invia via Resend
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: `4D Sistemi <${FROM_EMAIL}>`,
      to:   [ADMIN_EMAIL],
      subject: `⚠️ Audit Log 4D — dimensione ${size_mb} MB (soglia ${threshold})`,
      html,
    }),
  })

  const data = await res.json()

  if (!res.ok) {
    console.error("Resend error:", data)
    return new Response(JSON.stringify({ error: data }), { status: 500 })
  }

  return new Response(JSON.stringify({ ok: true, email_id: data.id }), {
    headers: { "Content-Type": "application/json" },
  })
})
