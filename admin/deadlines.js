// Green Lake /admin — motor de cálculo de plazos AEAT.
//
// IMPORTANTE: calcula las fechas según la norma general (día de vencimiento
// habitual de cada modelo). La AEAT desplaza algunas fechas cada año cuando
// caen en fin de semana o festivo (p.ej. en 2026 el modelo 200 se trasladó
// del 25 al 27 de julio). Estas fechas son orientativas — para operaciones
// críticas, confirma el día exacto en el calendario oficial de la AEAT del
// año en curso.

const QUARTERS = [
  { q: 1, endMonth: 4 },  // T1 (ene-mar) -> vence en abril
  { q: 2, endMonth: 7 },  // T2 (abr-jun) -> vence en julio
  { q: 3, endMonth: 10 }, // T3 (jul-sep) -> vence en octubre
  { q: 4, endMonth: 1 },  // T4 (oct-dic) -> vence en enero del año siguiente
];

function quarterlyInstances(obligationType, year) {
  return QUARTERS.map(({ q, endMonth }) => {
    const filingYear = q === 4 ? year + 1 : year;
    const extended = q === 4 && obligationType.quarterly_q4_extended;
    const endDay = extended ? 30 : 20;
    const domDay = extended ? 25 : 15;
    const hasDom = obligationType.domiciliacion_offset_days !== null && obligationType.domiciliacion_offset_days !== undefined;

    return {
      obligation: obligationType,
      period_label: `${q}ºT ${year}`,
      presentacion_end: new Date(filingYear, endMonth - 1, endDay),
      domiciliacion_end: hasDom ? new Date(filingYear, endMonth - 1, domDay) : null,
    };
  });
}

function annualInstances(obligationType, year) {
  if (!obligationType.deadline_end_month || !obligationType.deadline_end_day) return [];

  const endDate = new Date(year, obligationType.deadline_end_month - 1, obligationType.deadline_end_day);
  let domDate = null;
  const hasDom = obligationType.domiciliacion_offset_days !== null && obligationType.domiciliacion_offset_days !== undefined;
  if (hasDom) {
    domDate = new Date(endDate);
    domDate.setDate(domDate.getDate() - obligationType.domiciliacion_offset_days);
  }

  return [{
    obligation: obligationType,
    period_label: `${year}`,
    presentacion_end: endDate,
    domiciliacion_end: domDate,
  }];
}

// Genera las fechas del calendario para una obligación en un año concreto.
// Devuelve [] para periodicidad "puntual" (o "mensual", no soportada todavía):
// esos casos dependen de un hecho concreto (una venta, un alta...) y no de
// una fecha recurrente, así que no se listan automáticamente en el calendario.
function generateInstancesForYear(obligationType, year) {
  if (obligationType.periodicity === "trimestral") return quarterlyInstances(obligationType, year);
  if (obligationType.periodicity === "anual") return annualInstances(obligationType, year);
  return [];
}

// Todas las fechas (presentación y domiciliación) entre fromDate y fromDate+monthsAhead.
function getUpcomingInstances(obligationType, fromDate, monthsAhead) {
  const toDate = new Date(fromDate);
  toDate.setMonth(toDate.getMonth() + monthsAhead);

  const years = [fromDate.getFullYear(), fromDate.getFullYear() + 1];
  let all = [];
  years.forEach((y) => { all = all.concat(generateInstancesForYear(obligationType, y)); });

  return all
    .filter((inst) => inst.presentacion_end >= fromDate && inst.presentacion_end <= toDate)
    .sort((a, b) => a.presentacion_end - b.presentacion_end);
}

// Devuelve la instancia "actual" de una obligación periódica: la que tiene
// la fecha de presentación más próxima a hoy (ya sea reciente-pasada o
// futura). Se usa para el semáforo de estado de cada cliente.
function getRelevantInstance(obligationType, today) {
  const years = [today.getFullYear() - 1, today.getFullYear(), today.getFullYear() + 1];
  let all = [];
  years.forEach((y) => { all = all.concat(generateInstancesForYear(obligationType, y)); });
  if (all.length === 0) return null;
  all.sort((a, b) => Math.abs(a.presentacion_end - today) - Math.abs(b.presentacion_end - today));
  return all[0];
}

// Calcula el estado (ok / atencion / atrasado) de un cliente a partir de sus
// obligaciones activas (con su obligation_type embebido) y el conjunto de
// claves "clientId|obligationTypeId|period" ya presentadas.
function computeClientStatus(clientObligations, filedSet, clientId, today, warnDays) {
  let worst = "ok";
  clientObligations.forEach((co) => {
    const ot = co.obligation_types;
    if (!ot || (ot.periodicity !== "trimestral" && ot.periodicity !== "anual")) return;
    const inst = getRelevantInstance(ot, today);
    if (!inst) return;
    const key = clientId + "|" + ot.id + "|" + inst.period_label;
    if (filedSet.has(key)) return;
    const daysUntil = Math.round((inst.presentacion_end - today) / 86400000);
    if (daysUntil < 0) worst = "atrasado";
    else if (daysUntil <= warnDays && worst !== "atrasado") worst = "atencion";
  });
  return worst;
}

// Todas las fechas cuyo día de presentación O de domiciliación cae dentro
// del mes natural indicado (month: 0-11, igual que Date).
function getInstancesForMonth(obligationType, year, month) {
  const years = [year];
  // T4 de diciembre-año-anterior puede aterrizar en enero de "year"
  if (month === 0) years.push(year - 1);

  let all = [];
  years.forEach((y) => { all = all.concat(generateInstancesForYear(obligationType, y)); });

  return all.filter((inst) => {
    const inPresentacion = inst.presentacion_end.getFullYear() === year && inst.presentacion_end.getMonth() === month;
    const inDomiciliacion = inst.domiciliacion_end && inst.domiciliacion_end.getFullYear() === year && inst.domiciliacion_end.getMonth() === month;
    return inPresentacion || inDomiciliacion;
  });
}

function formatDate(date) {
  if (!date) return "—";
  return date.toLocaleDateString("es-ES", { day: "2-digit", month: "short", year: "numeric" });
}

const MONTH_NAMES_ES = ["enero","febrero","marzo","abril","mayo","junio","julio","agosto","septiembre","octubre","noviembre","diciembre"];
