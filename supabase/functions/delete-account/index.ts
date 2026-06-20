import "@supabase/functions-js/edge-runtime.d.ts"
import { withSupabase } from "@supabase/server"

export default {
  fetch: withSupabase({ auth: "user" }, async (request, ctx) => {
    if (request.method !== "DELETE") {
      return Response.json(
        { code: "method_not_allowed", message: "Use DELETE" },
        { status: 405, headers: { Allow: "DELETE" } },
      )
    }

    const userId = ctx.userClaims?.id
    if (!userId) {
      return Response.json(
        { code: "missing_user", message: "Invalid session" },
        { status: 401 },
      )
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(userId)
    if (error) {
      console.error("delete-account failed", {
        userId,
        code: error.code,
        status: error.status,
      })
      return Response.json(
        { code: "delete_failed", message: "Account could not be deleted" },
        { status: 500 },
      )
    }

    return new Response(null, { status: 204 })
  }),
}
