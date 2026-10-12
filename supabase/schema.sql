-- =====================================================================
--  Схема магазина для Supabase.
--  Выполните целиком в Supabase → SQL Editor → New query → Run.
--  Скрипт можно запускать повторно.
-- =====================================================================

-- ---------- Таблицы ----------

create table if not exists public.categories (
  id          text primary key,
  title       text not null,
  icon        text,
  image       text,
  color       text,
  sort        int  not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.products (
  id           text primary key default gen_random_uuid()::text,
  category_id  text references public.categories(id) on update cascade on delete set null,
  title        text not null,
  price        numeric(12,2),
  old_price    numeric(12,2),
  unit         text,
  images       text[]  not null default '{}',
  description  text    not null default '',
  badges       text[]  not null default '{}',
  options      jsonb   not null default '[]',   -- [{"name":"Размер","values":["S","M"]}]
  specs        jsonb   not null default '{}',   -- {"Состав":"хлопок"}
  in_stock     boolean not null default true,
  featured     boolean not null default false,
  active       boolean not null default true,   -- false = скрыт из приложения
  sort         int     not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists products_category_idx on public.products(category_id);

create table if not exists public.banners (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  subtitle     text,
  image        text,
  color        text,
  category_id  text references public.categories(id) on update cascade on delete set null,
  product_id   text references public.products(id)   on update cascade on delete set null,
  active       boolean not null default true,
  sort         int not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.orders (
  id              bigint generated always as identity primary key,
  created_at      timestamptz not null default now(),
  status          text not null default 'new'
                  check (status in ('new','confirmed','delivering','done','cancelled')),
  customer_name   text not null,
  customer_phone  text not null,
  address         text not null default '',
  is_delivery     boolean not null,
  payment         text not null,
  comment         text not null default '',
  lines           jsonb not null,        -- [{productId,title,options,price,quantity}]
  subtotal        numeric(12,2) not null,
  delivery_fee    numeric(12,2) not null default 0,
  total           numeric(12,2) not null,
  admin_note      text not null default '',
  discount        numeric(12,2) not null default 0,
  promo_code      text,
  bonus_spent     numeric(12,2) not null default 0,
  delivery_slot   text
);
create index if not exists orders_created_idx on public.orders(created_at desc);
-- Для баз, созданных старой версией схемы.
alter table public.orders add column if not exists discount numeric(12,2) not null default 0;
alter table public.orders add column if not exists promo_code text;
alter table public.orders add column if not exists bonus_spent numeric(12,2) not null default 0;
alter table public.orders add column if not exists delivery_slot text;

-- Тариф, переключатели функций, промокоды, бонусы — одна строка JSON (её правит админка).
create table if not exists public.app_settings (
  id    int primary key default 1 check (id = 1),
  data  jsonb not null default '{}'
);
insert into public.app_settings (id, data)
values (1, '{"plan":"premium","promoCodes":[{"code":"WELCOME10","percent":10,"amount":0,"minSum":0,"active":true}]}')
on conflict (id) do nothing;

-- Отзывы: клиенты добавляют, админ публикует.
create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  product_id  text not null references public.products(id) on update cascade on delete cascade,
  name        text not null default 'Покупатель',
  rating      int not null check (rating between 1 and 5),
  text        text not null default '',
  approved    boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists reviews_product_idx on public.reviews(product_id);

-- Кто может заходить в админку. Добавьте email владельца:
--   insert into public.admins(email) values ('owner@example.com');
create table if not exists public.admins (
  email text primary key
);

-- ---------- Функции ----------

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admins a
    where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

-- Оформление заказа из приложения. Цены пересчитываются по базе,
-- поэтому подменить стоимость на клиенте нельзя. Возвращает номер заказа.
create or replace function public.place_order(p jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  l         jsonb;
  prod      public.products;
  qty       int;
  lines     jsonb := '[]';
  sub       numeric := 0;
  fee       numeric := greatest(coalesce((p ->> 'deliveryFee')::numeric, 0), 0);
  new_id    bigint;
  cfg       jsonb;
  promo     jsonb;
  disc      numeric := 0;
  bonus     numeric := 0;
  code      text := upper(trim(coalesce(p ->> 'promoCode', '')));
begin
  if coalesce(trim(p #>> '{customer,name}'), '') = '' or coalesce(trim(p #>> '{customer,phone}'), '') = '' then
    raise exception 'name and phone are required';
  end if;
  if jsonb_typeof(p -> 'lines') <> 'array' or jsonb_array_length(p -> 'lines') = 0 then
    raise exception 'order is empty';
  end if;

  for l in select * from jsonb_array_elements(p -> 'lines') loop
    select * into prod from public.products
      where id = l ->> 'productId' and active and in_stock and price is not null;
    if not found then
      raise exception 'product % is unavailable', l ->> 'productId';
    end if;
    qty := least(greatest(coalesce((l ->> 'quantity')::int, 1), 1), 999);
    sub := sub + prod.price * qty;
    lines := lines || jsonb_build_object(
      'productId', prod.id,
      'title',     prod.title,
      'options',   coalesce(l -> 'options', '{}'),
      'price',     prod.price,
      'quantity',  qty
    );
  end loop;

  -- Промокод проверяется по настройкам на сервере, а не на слово клиента.
  select data into cfg from public.app_settings where id = 1;
  if code <> '' then
    select x into promo from jsonb_array_elements(coalesce(cfg -> 'promoCodes', '[]')) x
      where upper(x ->> 'code') = code and coalesce((x ->> 'active')::boolean, true)
      limit 1;
    if promo is not null and sub >= coalesce((promo ->> 'minSum')::numeric, 0) then
      disc := case when coalesce((promo ->> 'percent')::numeric, 0) > 0
                   then round(sub * (promo ->> 'percent')::numeric / 100)
                   else least(coalesce((promo ->> 'amount')::numeric, 0), sub) end;
    else
      code := null;
    end if;
  end if;
  -- Бонусы учитываются на устройстве клиента; на сервере — не больше разрешённой доли заказа.
  bonus := least(greatest(coalesce((p ->> 'bonusSpent')::numeric, 0), 0),
                 floor((sub - disc) * coalesce((cfg ->> 'loyaltyMaxSpendPercent')::numeric, 30) / 100));

  insert into public.orders (customer_name, customer_phone, address, is_delivery, payment, comment,
                             lines, subtotal, delivery_fee, discount, promo_code, bonus_spent, delivery_slot, total)
  values (
    left(trim(p #>> '{customer,name}'), 200),
    left(trim(p #>> '{customer,phone}'), 50),
    left(coalesce(p #>> '{customer,address}', ''), 500),
    coalesce((p ->> 'isDelivery')::boolean, false),
    left(coalesce(p ->> 'payment', 'cash'), 30),
    left(coalesce(p ->> 'comment', ''), 1000),
    lines, sub, fee, disc, nullif(code, ''), bonus, left(p ->> 'deliverySlot', 60),
    sub - disc - bonus + fee
  )
  returning id into new_id;
  return new_id;
end $$;

-- Лимит товаров по тарифу: Старт — 30, Бизнес — 500, Премиум — без ограничений.
create or replace function public.check_product_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  plan text := coalesce((select data ->> 'plan' from public.app_settings where id = 1), 'premium');
  lim  int := case plan when 'start' then 30 when 'business' then 500 else null end;
begin
  if lim is not null and (select count(*) from public.products) >= lim then
    raise exception 'Лимит тарифа: не больше % товаров', lim;
  end if;
  return new;
end $$;

drop trigger if exists products_limit on public.products;
create trigger products_limit before insert on public.products
  for each row execute function public.check_product_limit();

-- ---------- Права доступа (RLS) ----------

alter table public.categories enable row level security;
alter table public.products   enable row level security;
alter table public.banners    enable row level security;
alter table public.orders     enable row level security;
alter table public.admins     enable row level security;
alter table public.app_settings enable row level security;
alter table public.reviews    enable row level security;

-- Настройки читают все (приложению нужен тариф), меняют только админы.
drop policy if exists settings_read  on public.app_settings;
drop policy if exists settings_admin on public.app_settings;
create policy settings_read  on public.app_settings for select using (true);
create policy settings_admin on public.app_settings for all using (public.is_admin()) with check (public.is_admin());

-- Отзывы: опубликованные видят все; добавить может любой, но только неопубликованным; модерирует админ.
drop policy if exists reviews_read   on public.reviews;
drop policy if exists reviews_insert on public.reviews;
drop policy if exists reviews_admin  on public.reviews;
create policy reviews_read   on public.reviews for select using (approved or public.is_admin());
create policy reviews_insert on public.reviews for insert with check (not approved and rating between 1 and 5 and length(text) <= 2000);
create policy reviews_admin  on public.reviews for all using (public.is_admin()) with check (public.is_admin());
grant insert on public.reviews to anon, authenticated;

-- Каталог читают все, меняют только админы.
drop policy if exists categories_read  on public.categories;
drop policy if exists categories_admin on public.categories;
create policy categories_read  on public.categories for select using (true);
create policy categories_admin on public.categories for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists products_read  on public.products;
drop policy if exists products_admin on public.products;
create policy products_read  on public.products for select using (active or public.is_admin());
create policy products_admin on public.products for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists banners_read  on public.banners;
drop policy if exists banners_admin on public.banners;
create policy banners_read  on public.banners for select using (active or public.is_admin());
create policy banners_admin on public.banners for all using (public.is_admin()) with check (public.is_admin());

-- Заказы видят и меняют только админы. Создаются через place_order().
drop policy if exists orders_admin on public.orders;
create policy orders_admin on public.orders for all using (public.is_admin()) with check (public.is_admin());

-- Список админов из клиента не читается вообще (только через is_admin()).

grant execute on function public.place_order(jsonb) to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------- Хранилище картинок ----------

insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do update set public = true;

drop policy if exists images_admin_insert on storage.objects;
drop policy if exists images_admin_update on storage.objects;
drop policy if exists images_admin_delete on storage.objects;
create policy images_admin_insert on storage.objects for insert
  with check (bucket_id = 'images' and public.is_admin());
create policy images_admin_update on storage.objects for update
  using (bucket_id = 'images' and public.is_admin());
create policy images_admin_delete on storage.objects for delete
  using (bucket_id = 'images' and public.is_admin());
