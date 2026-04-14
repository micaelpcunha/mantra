import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  createServiceClient,
  jsonResponse,
  parseJsonBody,
  requireAdminContext,
} from "../_shared/email_provider_oauth.ts";

interface PlannedAssignmentSnapshot {
  asset_id: string;
  asset_name: string;
  location_name: string | null;
  technician_id: string;
  technician_name: string;
  planned_for: string;
}

interface WorkOrderSnapshot {
  id: string;
  reference: string | null;
  title: string;
  description: string | null;
  status: string;
  priority: string;
  asset_id: string | null;
  asset_name: string | null;
  location_name: string | null;
  technician_id: string | null;
  technician_name: string | null;
  scheduled_for: string | null;
  created_at: string | null;
  updated_at: string | null;
  observation_excerpt: string | null;
  has_photo: boolean;
  has_audio_note: boolean;
  blocker_signal: boolean;
}

interface SummaryStatsSnapshot {
  planned_assets_count: number;
  planned_technicians_count: number;
  touched_orders_count: number;
  created_orders_count: number;
  completed_orders_count: number;
  open_orders_count: number;
  urgent_open_orders_count: number;
  planned_without_activity_count: number;
}

interface SummaryContextSnapshot {
  summary_date: string;
  planned_assignments: PlannedAssignmentSnapshot[];
  orders_touched_today: WorkOrderSnapshot[];
  open_backlog: WorkOrderSnapshot[];
  source_stats: SummaryStatsSnapshot;
}

interface SummaryPayload {
  headline: string;
  completed: string[];
  unfinished: string[];
  blocked: string[];
  attention_tomorrow: string[];
  note: string;
}

interface OpenAiSummaryResult {
  payload: SummaryPayload;
  generationMode: "heuristic" | "openai";
  model: string | null;
  warning: string | null;
}

const openAiEndpoint = "https://api.openai.com/v1/responses";
const blockerKeywords = [
  "aguarda",
  "aguardar",
  "bloque",
  "falta material",
  "falta de material",
  "peca",
  "pecas",
  "sem material",
  "sem acesso",
  "parado",
  "indisponivel",
  "pendente cliente",
  "pendente fornecedor",
];

function normalizedText(value: unknown) {
  const text = value?.toString().trim() ?? "";
  return text.length === 0 ? null : text;
}

function readString(value: unknown, fallback = "") {
  return normalizedText(value) ?? fallback;
}

function readMap(value: unknown) {
  return value != null && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
}

function readDate(value: unknown) {
  const text = normalizedText(value);
  if (text == null) {
    return null;
  }

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeSummaryDate(value: unknown) {
  const text = normalizedText(value);
  if (text == null) {
    return null;
  }

  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function currentLisbonDateString() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Lisbon",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function dateStringInLisbon(value: string | null | undefined) {
  if (value == null || value.trim().length === 0) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Lisbon",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(parsed);
}

function subtractDaysIso(dateOnly: string, days: number) {
  const parsed = new Date(`${dateOnly}T00:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() - days);
  return parsed.toISOString();
}

function addDaysIso(dateOnly: string, days: number) {
  const parsed = new Date(`${dateOnly}T00:00:00Z`);
  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString();
}

function trimForSummary(value: unknown, maxLength = 220) {
  const text = normalizedText(value);
  if (text == null) {
    return null;
  }

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, Math.max(0, maxLength - 1)).trimEnd()}...`;
}

function priorityRank(priority: string) {
  switch (priority.toLowerCase()) {
    case "urgente":
      return 4;
    case "alta":
      return 3;
    case "normal":
      return 2;
    case "baixa":
    default:
      return 1;
  }
}

function compareWorkOrders(left: WorkOrderSnapshot, right: WorkOrderSnapshot) {
  const priorityDiff = priorityRank(right.priority) - priorityRank(left.priority);
  if (priorityDiff !== 0) {
    return priorityDiff;
  }

  return (
    (readDate(right.updated_at)?.getTime() ?? 0) -
    (readDate(left.updated_at)?.getTime() ?? 0)
  );
}

function isConcludedStatus(status: string) {
  return status.trim().toLowerCase() === "concluido";
}

function hasBlockerSignal(description: string | null, note: string | null) {
  const haystack = `${description ?? ""} ${note ?? ""}`.toLowerCase();
  return blockerKeywords.some((keyword) => haystack.includes(keyword));
}

function workOrderLabel(order: WorkOrderSnapshot) {
  const parts = <string>[];
  const reference = normalizedText(order.reference);
  if (reference != null) {
    parts.push(reference);
  }

  parts.push(order.title);

  if (order.asset_name != null && order.asset_name.trim().length > 0) {
    parts.push(order.asset_name.trim());
  }

  if (order.technician_name != null && order.technician_name.trim().length > 0) {
    parts.push(order.technician_name.trim());
  }

  return parts.join(" | ");
}

function plannedAssignmentLabel(assignment: PlannedAssignmentSnapshot) {
  const parts = [assignment.asset_name, assignment.technician_name];
  if (
    assignment.location_name != null &&
    assignment.location_name.trim().length > 0
  ) {
    parts.push(assignment.location_name.trim());
  }
  return parts.join(" | ");
}

function normalizeSummaryPayload(raw: unknown): SummaryPayload {
  const map = readMap(raw);
  const readItems = (value: unknown) =>
    Array.isArray(value)
      ? value
        .map((item) => normalizedText(item))
        .filter((item): item is string => item != null)
        .slice(0, 6)
      : [];

  return {
    headline: normalizedText(map["headline"]) ??
      "Resumo operacional gerado com os registos do dia.",
    completed: readItems(map["completed"]),
    unfinished: readItems(map["unfinished"]),
    blocked: readItems(map["blocked"]),
    attention_tomorrow: readItems(map["attention_tomorrow"]),
    note: normalizedText(map["note"]) ?? "",
  };
}

function buildSummaryText(payload: SummaryPayload) {
  const lines = [payload.headline];
  const sections: Array<[string, string[]]> = [
    ["Feito hoje", payload.completed],
    ["Por concluir", payload.unfinished],
    ["Bloqueios", payload.blocked],
    ["Atencao para amanha", payload.attention_tomorrow],
  ];

  for (const [title, items] of sections) {
    lines.push("");
    lines.push(`${title}:`);
    if (items.length === 0) {
      lines.push("- Sem registos relevantes.");
      continue;
    }

    for (const item of items) {
      lines.push(`- ${item}`);
    }
  }

  if (payload.note.trim().length > 0) {
    lines.push("");
    lines.push(`Nota: ${payload.note.trim()}`);
  }

  return lines.join("\n");
}

function buildHeuristicSummary(context: SummaryContextSnapshot): SummaryPayload {
  const completed = context.orders_touched_today
    .filter((order) => isConcludedStatus(order.status))
    .sort(compareWorkOrders)
    .slice(0, 5)
    .map((order) => `${workOrderLabel(order)} concluida`);

  const unfinishedFromOrders = context.orders_touched_today
    .filter((order) => !isConcludedStatus(order.status))
    .sort(compareWorkOrders)
    .slice(0, 4)
    .map((order) => `${workOrderLabel(order)} continua em ${order.status}`);

  const plannedWithoutActivity = context.planned_assignments
    .filter((assignment) =>
      !context.orders_touched_today.some((order) =>
        order.asset_id === assignment.asset_id &&
        (order.technician_id == null ||
          order.technician_id === assignment.technician_id)
      )
    )
    .slice(0, 4)
    .map((assignment) =>
      `${plannedAssignmentLabel(assignment)} sem atividade registada`
    );

  const blocked = context.open_backlog
    .filter((order) => order.blocker_signal)
    .slice(0, 4)
    .map((order) =>
      order.observation_excerpt == null
        ? `${workOrderLabel(order)} com sinal de bloqueio nas notas`
        : `${workOrderLabel(order)}: ${order.observation_excerpt}`
    );

  const attentionTomorrow = [
    ...context.open_backlog
      .filter((order) => priorityRank(order.priority) >= 3)
      .slice(0, 3)
      .map((order) => `${workOrderLabel(order)} continua prioritario`),
    ...plannedWithoutActivity.slice(0, 2),
  ].slice(0, 5);

  return {
    headline:
      "O dia ficou marcado pela atividade registada nas ordens atualizadas e pelo backlog que ainda segue aberto.",
    completed: completed.isEmpty
      ? ["Nao ha ordens marcadas como concluidas nos registos do dia."]
      : completed,
    unfinished: unfinishedFromOrders.isEmpty
      ? (plannedWithoutActivity.isEmpty
          ? ["Nao ficaram pendencias relevantes nos registos do dia."]
          : plannedWithoutActivity)
      : [...unfinishedFromOrders, ...plannedWithoutActivity].slice(0, 5),
    blocked: blocked.isEmpty
      ? ["Nao foram encontrados bloqueios explicitos nas notas tecnicas."]
      : blocked,
    attention_tomorrow: attentionTomorrow.isEmpty
      ? ["Sem alertas prioritarios adicionais para amanha."]
      : attentionTomorrow,
    note: context.source_stats.planned_without_activity_count > 0
      ? "Existem ativos planeados sem atividade registada no dia."
      : "",
  };
}

async function generateOpenAiSummary(
  context: SummaryContextSnapshot,
): Promise<OpenAiSummaryResult> {
  const apiKey = Deno.env.get("OPENAI_API_KEY")?.trim();
  if (apiKey == null || apiKey.length === 0) {
    return {
      payload: buildHeuristicSummary(context),
      generationMode: "heuristic",
      model: null,
      warning:
        "OPENAI_API_KEY nao configurada no Supabase. Foi usado um resumo local.",
    };
  }

  const model = Deno.env.get("OPENAI_DAILY_SUMMARY_MODEL")?.trim() ||
    "gpt-5-mini";
  const response = await fetch(openAiEndpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      input: [
        {
          role: "developer",
          content: [
            {
              type: "input_text",
              text:
                "Escreve um resumo operacional fiel aos dados recebidos. Responde em portugues europeu. Nao inventes causas, bloqueios nem atividades. Se nao houver prova suficiente, assume isso. O tom deve ser curto, direto e util para o admin preparar o dia seguinte.",
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: JSON.stringify({
                objective:
                  "Explicar o que foi feito hoje, o que ficou por concluir, o que esta bloqueado e o que merece atencao amanha.",
                context,
              }),
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: "daily_operations_summary",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              headline: { type: "string" },
              completed: {
                type: "array",
                items: { type: "string" },
                maxItems: 6,
              },
              unfinished: {
                type: "array",
                items: { type: "string" },
                maxItems: 6,
              },
              blocked: {
                type: "array",
                items: { type: "string" },
                maxItems: 6,
              },
              attention_tomorrow: {
                type: "array",
                items: { type: "string" },
                maxItems: 6,
              },
              note: { type: "string" },
            },
            required: [
              "headline",
              "completed",
              "unfinished",
              "blocked",
              "attention_tomorrow",
              "note",
            ],
          },
        },
      },
    }),
  });

  const rawPayload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const payloadMap = readMap(rawPayload);
    const errorMap = readMap(payloadMap["error"]);
    throw new Error(
      normalizedText(errorMap["message"]) ??
        normalizedText(payloadMap["message"]) ??
        "Falha ao gerar o resumo com OpenAI.",
    );
  }

  const outputText = extractResponseOutputText(readMap(rawPayload));
  if (outputText == null) {
    throw new Error("A OpenAI nao devolveu conteudo utilizavel.");
  }

  return {
    payload: normalizeSummaryPayload(JSON.parse(outputText)),
    generationMode: "openai",
    model,
    warning: null,
  };
}

function extractResponseOutputText(response: Record<string, unknown>) {
  const direct = normalizedText(response["output_text"]);
  if (direct != null) {
    return direct;
  }

  const output = response["output"];
  if (!Array.isArray(output)) {
    return null;
  }

  const texts: string[] = [];
  for (const item of output) {
    const content = readMap(item)["content"];
    if (!Array.isArray(content)) {
      continue;
    }

    for (const contentItem of content) {
      const text = normalizedText(readMap(contentItem)["text"]);
      if (text != null) {
        texts.push(text);
      }
    }
  }

  return texts.length === 0 ? null : texts.join("\n");
}

async function fetchRowsByIds(
  table: string,
  fields: string,
  ids: string[],
): Promise<Record<string, unknown>[]> {
  if (ids.length === 0) {
    return [];
  }

  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient
    .from(table)
    .select(fields)
    .in("id", ids);

  if (error != null) {
    throw new Error(`Nao foi possivel carregar registos de ${table}.`);
  }

  return (data ?? []) as Record<string, unknown>[];
}

async function fetchContext(
  companyId: string,
  summaryDate: string,
): Promise<SummaryContextSnapshot> {
  const serviceClient = createServiceClient();
  const workOrderFields =
    "id, reference, title, description, status, priority, asset_id, technician_id, comment, photo_url, audio_note_url, scheduled_for, created_at, updated_at";
  const wideStartIso = subtractDaysIso(summaryDate, 1);
  const wideEndIso = addDaysIso(summaryDate, 2);

  const [
    plannedResult,
    updatedResult,
    createdResult,
    openResult,
  ] = await Promise.all([
    serviceClient
      .from("planned_day_assets")
      .select("asset_id, technician_id, planned_for")
      .eq("company_id", companyId)
      .eq("planned_for", summaryDate),
    serviceClient
      .from("work_orders")
      .select(workOrderFields)
      .eq("company_id", companyId)
      .gte("updated_at", wideStartIso)
      .lt("updated_at", wideEndIso)
      .order("updated_at", { ascending: false })
      .limit(150),
    serviceClient
      .from("work_orders")
      .select(workOrderFields)
      .eq("company_id", companyId)
      .gte("created_at", wideStartIso)
      .lt("created_at", wideEndIso)
      .order("created_at", { ascending: false })
      .limit(150),
    serviceClient
      .from("work_orders")
      .select(workOrderFields)
      .eq("company_id", companyId)
      .neq("status", "concluido")
      .order("updated_at", { ascending: false })
      .limit(60),
  ]);

  if (plannedResult.error != null) {
    throw new Error("Nao foi possivel carregar o planeamento diario.");
  }
  if (updatedResult.error != null) {
    throw new Error("Nao foi possivel carregar as ordens atualizadas no dia.");
  }
  if (createdResult.error != null) {
    throw new Error("Nao foi possivel carregar as ordens criadas no dia.");
  }
  if (openResult.error != null) {
    throw new Error("Nao foi possivel carregar o backlog em aberto.");
  }

  const plannedRows = (plannedResult.data ?? []) as Record<string, unknown>[];
  const updatedRows = (updatedResult.data ?? []) as Record<string, unknown>[];
  const createdRows = (createdResult.data ?? []) as Record<string, unknown>[];
  const openRows = (openResult.data ?? []) as Record<string, unknown>[];

  const mergedOrdersById = new Map<string, Record<string, unknown>>();
  for (const row of [...updatedRows, ...createdRows, ...openRows]) {
    const id = normalizedText(row["id"]);
    if (id != null) {
      mergedOrdersById.set(id, row);
    }
  }

  const assetIds = new Set<string>();
  const technicianIds = new Set<string>();
  for (const row of plannedRows) {
    const assetId = normalizedText(row["asset_id"]);
    const technicianId = normalizedText(row["technician_id"]);
    if (assetId != null) assetIds.add(assetId);
    if (technicianId != null) technicianIds.add(technicianId);
  }

  for (const row of mergedOrdersById.values()) {
    const assetId = normalizedText(row["asset_id"]);
    const technicianId = normalizedText(row["technician_id"]);
    if (assetId != null) assetIds.add(assetId);
    if (technicianId != null) technicianIds.add(technicianId);
  }

  const assetRows = await fetchRowsByIds("assets", "id, name, location_id", [
    ...assetIds,
  ]);
  const locationIds = assetRows
    .map((row) => normalizedText(row["location_id"]))
    .filter((value): value is string => value != null);
  const locationRows = await fetchRowsByIds("locations", "id, name", locationIds);
  const technicianRows = await fetchRowsByIds("technicians", "id, name", [
    ...technicianIds,
  ]);

  const assetsById = new Map<string, Record<string, unknown>>();
  for (const row of assetRows) {
    assetsById.set(readString(row["id"]), row);
  }

  const locationsById = new Map<string, Record<string, unknown>>();
  for (const row of locationRows) {
    locationsById.set(readString(row["id"]), row);
  }

  const techniciansById = new Map<string, Record<string, unknown>>();
  for (const row of technicianRows) {
    techniciansById.set(readString(row["id"]), row);
  }

  const allPlannedAssignments = plannedRows
    .map((row) => {
      const assetId = readString(row["asset_id"]);
      const technicianId = readString(row["technician_id"]);
      const asset = assetsById.get(assetId);
      const locationId = normalizedText(asset?.["location_id"]);
      const location = locationId == null ? null : locationsById.get(locationId);
      const technician = techniciansById.get(technicianId);

      return {
        asset_id: assetId,
        asset_name: normalizedText(asset?.["name"]) ?? "Ativo sem nome",
        location_name: normalizedText(location?.["name"]),
        technician_id: technicianId,
        technician_name:
          normalizedText(technician?.["name"]) ?? "Tecnico sem nome",
        planned_for: readString(row["planned_for"], summaryDate),
      };
    })
    .sort((left, right) => left.asset_name.localeCompare(right.asset_name));

  const allOrders = [...mergedOrdersById.values()].map((row) => {
    const assetId = normalizedText(row["asset_id"]);
    const technicianId = normalizedText(row["technician_id"]);
    const asset = assetId == null ? null : assetsById.get(assetId);
    const locationId = normalizedText(asset?.["location_id"]);
    const location = locationId == null ? null : locationsById.get(locationId);
    const technician = technicianId == null ? null : techniciansById.get(technicianId);
    const description = trimForSummary(row["description"], 180);
    const note = trimForSummary(row["comment"], 180);

    return {
      id: readString(row["id"]),
      reference: normalizedText(row["reference"]),
      title:
        trimForSummary(row["title"], 90) ??
        description ??
        "Ordem sem titulo",
      description,
      status: readString(row["status"], "pendente"),
      priority: readString(row["priority"], "normal"),
      asset_id: assetId,
      asset_name: normalizedText(asset?.["name"]),
      location_name: normalizedText(location?.["name"]),
      technician_id: technicianId,
      technician_name: normalizedText(technician?.["name"]),
      scheduled_for: normalizedText(row["scheduled_for"]),
      created_at: normalizedText(row["created_at"]),
      updated_at: normalizedText(row["updated_at"]),
      observation_excerpt: note,
      has_photo: normalizedText(row["photo_url"]) != null,
      has_audio_note: normalizedText(row["audio_note_url"]) != null,
      blocker_signal: hasBlockerSignal(description, note),
    };
  });

  const allTouchedOrders = allOrders
    .filter((order) =>
      dateStringInLisbon(order.created_at) === summaryDate ||
      dateStringInLisbon(order.updated_at) === summaryDate
    )
    .sort(compareWorkOrders);

  const allOpenBacklog = allOrders
    .filter((order) => !isConcludedStatus(order.status))
    .sort(compareWorkOrders);

  const createdOrdersCount = allTouchedOrders.filter((order) =>
    dateStringInLisbon(order.created_at) === summaryDate
  ).length;
  const completedOrdersCount = allTouchedOrders.filter((order) =>
    isConcludedStatus(order.status)
  ).length;
  const plannedWithoutActivityCount = allPlannedAssignments.filter((assignment) =>
    !allTouchedOrders.some((order) =>
      order.asset_id === assignment.asset_id &&
      (order.technician_id == null ||
        order.technician_id === assignment.technician_id)
    )
  ).length;

  return {
    summary_date: summaryDate,
    planned_assignments: allPlannedAssignments.slice(0, 30),
    orders_touched_today: allTouchedOrders.slice(0, 25),
    open_backlog: allOpenBacklog.slice(0, 15),
    source_stats: {
      planned_assets_count: allPlannedAssignments.length,
      planned_technicians_count:
        new Set(allPlannedAssignments.map((item) => item.technician_id)).size,
      touched_orders_count: allTouchedOrders.length,
      created_orders_count: createdOrdersCount,
      completed_orders_count: completedOrdersCount,
      open_orders_count: allOpenBacklog.length,
      urgent_open_orders_count: allOpenBacklog.filter((order) =>
        priorityRank(order.priority) >= 3
      ).length,
      planned_without_activity_count: plannedWithoutActivityCount,
    },
  };
}

async function upsertSummary(params: {
  companyId: string;
  summaryDate: string;
  generatedBy: string;
  status: "ready" | "failed";
  summaryPayload: SummaryPayload | null;
  summaryText: string | null;
  sourcePayload: SummaryContextSnapshot | null;
  sourceStats: SummaryStatsSnapshot | null;
  generationMode: "heuristic" | "openai";
  model: string | null;
  errorMessage: string | null;
}) {
  const serviceClient = createServiceClient();
  const { data, error } = await serviceClient
    .from("daily_ai_summaries")
    .upsert({
      company_id: params.companyId,
      summary_date: params.summaryDate,
      status: params.status,
      summary_payload: params.summaryPayload ?? {},
      summary_text: params.summaryText,
      source_payload: params.sourcePayload ?? {},
      source_stats: params.sourceStats ?? {},
      generation_mode: params.generationMode,
      model: params.model,
      error_message: params.errorMessage,
      generated_by: params.generatedBy,
      generated_at: new Date().toISOString(),
    }, {
      onConflict: "company_id,summary_date",
    })
    .select()
    .single();

  if (error != null) {
    throw new Error("Nao foi possivel guardar o resumo diario.");
  }

  return data;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let companyId: string | null = null;
  let userId: string | null = null;
  let summaryDate: string | null = null;
  let sourcePayload: SummaryContextSnapshot | null = null;

  try {
    const admin = await requireAdminContext(req, {
      nonAdminMessage: "Apenas administradores podem gerar o resumo do dia.",
    });
    companyId = admin.companyId;
    userId = admin.userId;

    const body = await parseJsonBody(req);
    summaryDate = normalizeSummaryDate(body["summary_date"]) ??
      currentLisbonDateString();
    sourcePayload = await fetchContext(companyId, summaryDate);

    let summaryPayload: SummaryPayload;
    let generationMode: "heuristic" | "openai" = "heuristic";
    let model: string | null = null;
    let warning: string | null = null;

    try {
      const openAiSummary = await generateOpenAiSummary(sourcePayload);
      summaryPayload = openAiSummary.payload;
      generationMode = openAiSummary.generationMode;
      model = openAiSummary.model;
      warning = openAiSummary.warning;
    } catch (error) {
      console.error("daily-operations-summary openai failed", error);
      summaryPayload = buildHeuristicSummary(sourcePayload);
      warning =
        "Falhou a geracao com OpenAI. Foi usado um resumo local para nao bloquear o dashboard.";
    }

    const savedSummary = await upsertSummary({
      companyId,
      summaryDate,
      generatedBy: userId,
      status: "ready",
      summaryPayload,
      summaryText: buildSummaryText(summaryPayload),
      sourcePayload,
      sourceStats: sourcePayload.source_stats,
      generationMode,
      model,
      errorMessage: null,
    });

    return jsonResponse({
      summary: savedSummary,
      warning,
      message: warning,
    });
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Nao foi possivel gerar o resumo diario.";

    if (companyId != null && userId != null && summaryDate != null) {
      try {
        await upsertSummary({
          companyId,
          summaryDate,
          generatedBy: userId,
          status: "failed",
          summaryPayload: null,
          summaryText: null,
          sourcePayload,
          sourceStats: sourcePayload?.source_stats ?? null,
          generationMode: "heuristic",
          model: null,
          errorMessage: message,
        });
      } catch (persistError) {
        console.error(
          "daily-operations-summary failed to persist failure",
          persistError,
        );
      }
    }

    return jsonResponse({ error: message }, 400);
  }
});
