import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 📥 Lê dados enviados pelo app
    const { nova_senha } = await req.json();

    // 🔐 Validação da senha
    if (!nova_senha || nova_senha.length < 6) {
      return new Response(
        JSON.stringify({ success: false, error: "A nova senha deve ter pelo menos 6 caracteres" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseUrl = Deno.env.get("PROJECT_URL")!;
    const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // 🔹 Obtém o usuário atual do token JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Token de autenticação não encontrado" }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: userError } = await supabase.auth.getUser(token);
    
    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Usuário não autenticado: " + (userError?.message || "Token inválido") }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const userId = user.id;

    // 1️⃣ Atualiza a senha no Auth
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: nova_senha }
    );

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: "Erro ao atualizar senha: " + updateError.message }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2️⃣ Atualiza a flag senha_temporaria para FALSE (se existir na sua tabela)
    const { error: dbError } = await supabase
      .from("usuarios")
      .update({ senha_temporaria: false })
      .eq("id", userId);

    if (dbError) {
      // Não lança erro, apenas loga, pois a atualização da senha já foi feita
      console.log("Aviso: Não foi possível atualizar senha_temporaria:", dbError.message);
    }

    // ✅ Retorna sucesso
    return new Response(
      JSON.stringify({
        success: true,
        message: "Senha alterada com sucesso!",
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    console.error("❌ Erro em alterar-senha:", errorMessage);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});