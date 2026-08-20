-- Green Lake /admin — avisos automáticos por email de obligaciones próximas o atrasadas.
--
-- Requisitos previos (hacer una sola vez, en este orden):
--   1. Crear cuenta en https://resend.com (plan gratuito: 3.000 emails/mes).
--   2. En Resend, añadir y verificar el dominio greenlaketax.com (te dará
--      registros DNS tipo TXT/MX/CNAME — se añaden en el panel DNS de
--      Squarespace, igual que hicimos con los registros del dominio).
--      Mientras no esté verificado, puedes probar usando remitente
--      "onboarding@resend.dev" en vez de "avisos@greenlaketax.com" más abajo.
--   3. En Resend, generar una API key (Dashboard > API Keys > Create).
--   4. En Supabase: Database > Extensions, activar "pg_cron" y "pg_net" (buscar
--      cada una en el buscador de extensiones y activarlas). El Vault ya viene
--      activado por defecto.
--   5. Guardar la API key de Resend en el Vault (sustituye TU_API_KEY_DE_RESEND
--      por la key real, ejecuta esta línea UNA sola vez en el SQL Editor):
--
--        select vault.create_secret('TU_API_KEY_DE_RESEND', 'resend_api_key', 'Resend — avisos Green Lake');
--
--   6. Ejecutar el resto de este script.
--   7. Probar manualmente: select public.send_deadline_alert_email();
--      (si hay obligaciones próximas/atrasadas sin presentar, te llegará un
--      email a e.torregrosa.v@gmail.com en segundos).

-- Calcula, para cada obligación activa de cada cliente, el periodo "relevante"
-- (el más cercano a hoy) y lo devuelve si vence en los próximos `warn_days`
-- días o si ya está atrasado, y todavía no se ha marcado como presentado.
create or replace function public.upcoming_deadline_alerts(warn_days int default 7)
returns table (
  client_name text,
  client_id uuid,
  obligation_name text,
  obligation_type_id uuid,
  period_label text,
  due_date date,
  days_until int,
  kind text
)
language sql
stable
as $$
  with years as (
    select unnest(array[
      extract(year from current_date)::int - 1,
      extract(year from current_date)::int,
      extract(year from current_date)::int + 1
    ]) as yr
  ),
  trimestral_instances as (
    select
      co.client_id,
      c.name as client_name,
      ot.id as obligation_type_id,
      ot.name as obligation_name,
      (q.quarter || 'ºT ' || years.yr) as period_label,
      make_date(
        case when q.quarter = 4 then years.yr + 1 else years.yr end,
        case q.quarter when 1 then 4 when 2 then 7 when 3 then 10 when 4 then 1 end,
        case when q.quarter = 4 and ot.quarterly_q4_extended then 30 else 20 end
      ) as due_date
    from client_obligations co
    join obligation_types ot on ot.id = co.obligation_type_id
    join clients c on c.id = co.client_id
    cross join unnest(array[1,2,3,4]) as q(quarter)
    cross join years
    where co.active = true and ot.periodicity = 'trimestral'
  ),
  anual_instances as (
    select
      co.client_id,
      c.name as client_name,
      ot.id as obligation_type_id,
      ot.name as obligation_name,
      years.yr::text as period_label,
      make_date(years.yr, ot.deadline_end_month, ot.deadline_end_day) as due_date
    from client_obligations co
    join obligation_types ot on ot.id = co.obligation_type_id
    join clients c on c.id = co.client_id
    cross join years
    where co.active = true and ot.periodicity = 'anual'
      and ot.deadline_end_month is not null and ot.deadline_end_day is not null
  ),
  all_instances as (
    select * from trimestral_instances
    union all
    select * from anual_instances
  ),
  ranked as (
    select
      i.*,
      row_number() over (
        partition by i.client_id, i.obligation_type_id
        order by abs(i.due_date - current_date)
      ) as rn
    from all_instances i
  )
  select
    r.client_name,
    r.client_id,
    r.obligation_name,
    r.obligation_type_id,
    r.period_label,
    r.due_date,
    (r.due_date - current_date)::int as days_until,
    case when r.due_date < current_date then 'atrasado' else 'proximo' end as kind
  from ranked r
  where r.rn = 1
    and (r.due_date - current_date) <= warn_days
    and not exists (
      select 1 from obligation_filings f
      where f.client_id = r.client_id
        and f.obligation_type_id = r.obligation_type_id
        and f.period_label = r.period_label
        and f.filed = true
    )
  order by r.due_date asc;
$$;

-- Construye el email en HTML y lo envía vía la API de Resend usando pg_net.
-- No hace nada (y no gasta llamadas) si no hay ninguna alerta relevante hoy.
create or replace function public.send_deadline_alert_email()
returns void
language plpgsql
security definer
set search_path = public, extensions, vault
as $$
declare
  api_key text;
  alert_count int;
  html_rows text := '';
  html_body text;
  rec record;
begin
  select decrypted_secret into api_key
  from vault.decrypted_secrets
  where name = 'resend_api_key';

  if api_key is null then
    raise notice 'Green Lake: no hay resend_api_key en el Vault, no se envía aviso.';
    return;
  end if;

  select count(*) into alert_count from public.upcoming_deadline_alerts(7);
  if alert_count = 0 then
    return;
  end if;

  for rec in select * from public.upcoming_deadline_alerts(7) loop
    html_rows := html_rows || format(
      '<tr>
         <td style="padding:7px 12px;border-bottom:1px solid #e5e0d5;">%s</td>
         <td style="padding:7px 12px;border-bottom:1px solid #e5e0d5;">%s</td>
         <td style="padding:7px 12px;border-bottom:1px solid #e5e0d5;">%s</td>
         <td style="padding:7px 12px;border-bottom:1px solid #e5e0d5;color:%s;font-weight:600;">%s</td>
       </tr>',
      rec.client_name,
      rec.obligation_name,
      rec.period_label,
      case when rec.kind = 'atrasado' then '#a1502a' else '#93732f' end,
      case when rec.kind = 'atrasado'
        then 'Atrasado desde el ' || to_char(rec.due_date, 'DD/MM/YYYY')
        else 'Vence el ' || to_char(rec.due_date, 'DD/MM/YYYY') || ' (' || rec.days_until || ' días)'
      end
    );
  end loop;

  html_body := format(
    '<div style="font-family:Georgia,serif;max-width:600px;margin:0 auto;color:#1f2a24;">
       <h2 style="color:#2D6A4F;margin-bottom:6px;">Green Lake — Obligaciones que requieren atención</h2>
       <p style="color:#4a4a42;">Resumen automático de obligaciones fiscales atrasadas o que vencen en los próximos 7 días, todavía sin marcar como presentadas.</p>
       <table style="width:100%%;border-collapse:collapse;font-size:14px;margin-top:14px;">
         <thead>
           <tr style="background:#f7f5ef;text-align:left;">
             <th style="padding:7px 12px;">Cliente</th>
             <th style="padding:7px 12px;">Obligación</th>
             <th style="padding:7px 12px;">Periodo</th>
             <th style="padding:7px 12px;">Estado</th>
           </tr>
         </thead>
         <tbody>%s</tbody>
       </table>
       <p style="margin-top:20px;font-size:12px;color:#8a8578;">Revisa el detalle y márcalas como presentadas en tu panel de Green Lake.</p>
     </div>',
    html_rows
  );

  perform net.http_post(
    url := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || api_key,
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'from', 'Green Lake <avisos@greenlaketax.com>',
      'to', jsonb_build_array('e.torregrosa.v@gmail.com'),
      'subject', alert_count || ' obligación(es) fiscal(es) requieren atención — Green Lake',
      'html', html_body
    )
  );
end;
$$;

-- Programa el envío todos los días laborables a las 07:00 hora de España
-- (05:00 UTC en horario de verano / 06:00 UTC en horario de invierno — se deja
-- fijo en 06:00 UTC como término medio razonable; ajusta si lo prefieres).
select cron.schedule(
  'greenlake-deadline-alerts',
  '0 6 * * 1-5',
  $$select public.send_deadline_alert_email();$$
);

-- Para desprogramarlo en el futuro:
-- select cron.unschedule('greenlake-deadline-alerts');
