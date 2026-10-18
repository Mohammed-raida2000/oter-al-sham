-- Oter Al-Sham Association Cooperative — PostgreSQL schema v0.1 (design draft, Phase 1)
-- Decisions: ID number and phone are MANDATORY for a family; receipt is confirmed by ID.
-- ASSUMPTION pending confirmation: ID = 9 digits; phone = 10 digits starting with 0.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE record_status AS ENUM ('draft','pending_review','needs_correction','approved','archived');
CREATE TYPE entity_status AS ENUM ('active','inactive','archived');
CREATE TYPE project_status AS ENUM ('planned','active','completed','suspended','archived');
CREATE TYPE distribution_status AS ENUM ('scheduled','in_progress','completed','cancelled');
CREATE TYPE distribution_mode AS ENUM ('names_only','full_documentation');
CREATE TYPE need_status AS ENUM ('open','in_progress','met','closed');

-- ---------- Users, roles, permissions ----------
CREATE TABLE roles (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,             -- admin, field_researcher, supervisor, distribution_officer
  name_ar text NOT NULL, name_en text NOT NULL
);
CREATE TABLE permissions (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,             -- e.g. family.create, family.approve, report.export
  description text
);
CREATE TABLE role_permissions (
  role_id smallint NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id smallint NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);
CREATE TABLE users (
  id bigserial PRIMARY KEY,
  username citext NOT NULL UNIQUE,
  full_name text NOT NULL,
  phone text,
  password_hash text NOT NULL,           -- bcrypt/argon2 only, never plaintext
  role_id smallint NOT NULL REFERENCES roles(id),
  is_active boolean NOT NULL DEFAULT true,
  locale text NOT NULL DEFAULT 'ar' CHECK (locale IN ('ar','en')),
  theme text NOT NULL DEFAULT 'light' CHECK (theme IN ('light','dark')),
  created_by bigint REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deactivated_at timestamptz
);

-- ---------- Camps ----------
CREATE TABLE camps (
  id bigserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  governorate text NOT NULL, area text NOT NULL,
  address_detail text,
  latitude numeric(9,6), longitude numeric(9,6),
  representative_name text, representative_phone text,
  status entity_status NOT NULL DEFAULT 'active',
  created_by bigint REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX camps_name_trgm ON camps USING gin (name gin_trgm_ops);

-- ---------- Families ----------
CREATE SEQUENCE family_no_seq START 1;
CREATE TABLE families (
  id bigserial PRIMARY KEY,
  family_no text NOT NULL UNIQUE DEFAULT ('F-' || lpad(nextval('family_no_seq')::text, 6, '0')),
  head_name text NOT NULL,
  id_number text NOT NULL UNIQUE CHECK (id_number ~ '^[0-9]{9}$'),
  phone text NOT NULL CHECK (phone ~ '^0[0-9]{9}$'),
  governorate text, area text,
  current_camp_id bigint NOT NULL REFERENCES camps(id),
  address_detail text,
  registered_on date NOT NULL DEFAULT current_date,
  created_by bigint NOT NULL REFERENCES users(id),
  status record_status NOT NULL DEFAULT 'draft',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX families_phone_idx ON families (phone);
CREATE INDEX families_camp_idx ON families (current_camp_id);
CREATE INDEX families_status_idx ON families (status);
CREATE INDEX families_name_trgm ON families USING gin (head_name gin_trgm_ops);

CREATE TABLE family_members (
  id bigserial PRIMARY KEY,
  family_id bigint NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  relation text NOT NULL,
  birth_date date CHECK (birth_date <= current_date),
  gender text CHECK (gender IN ('male','female')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX family_members_family_idx ON family_members (family_id);

CREATE TABLE need_types (               -- approved catalogue managed by the organisation
  id smallserial PRIMARY KEY, name_ar text NOT NULL, name_en text, is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE family_needs (
  id bigserial PRIMARY KEY,
  family_id bigint NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  need_type_id smallint NOT NULL REFERENCES need_types(id),
  status need_status NOT NULL DEFAULT 'open',
  notes text,
  recorded_by bigint NOT NULL REFERENCES users(id),
  recorded_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE family_camp_history (
  id bigserial PRIMARY KEY,
  family_id bigint NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  from_camp_id bigint REFERENCES camps(id),
  to_camp_id bigint NOT NULL REFERENCES camps(id),
  moved_at timestamptz NOT NULL DEFAULT now(),
  recorded_by bigint REFERENCES users(id)
);
CREATE INDEX family_camp_history_family_idx ON family_camp_history (family_id, moved_at);

CREATE TABLE family_reviews (
  id bigserial PRIMARY KEY,
  family_id bigint NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  reviewer_id bigint NOT NULL REFERENCES users(id),
  decision text NOT NULL CHECK (decision IN ('approved','needs_correction')),
  comment text,
  reviewed_at timestamptz NOT NULL DEFAULT now(),
  CHECK (decision = 'approved' OR comment IS NOT NULL)   -- a return for correction needs a reason
);

CREATE TABLE field_visits (
  id bigserial PRIMARY KEY,
  camp_id bigint NOT NULL REFERENCES camps(id),
  researcher_id bigint NOT NULL REFERENCES users(id),
  visited_on date NOT NULL DEFAULT current_date,
  notes text
);

-- ---------- Projects ----------
CREATE TABLE projects (
  id bigserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  project_type text NOT NULL,
  description text,
  starts_on date, ends_on date,
  target_groups text, target_family_count integer CHECK (target_family_count >= 0),
  status project_status NOT NULL DEFAULT 'planned',
  created_by bigint REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_on IS NULL OR starts_on IS NULL OR ends_on >= starts_on)
);
CREATE TABLE project_camps (
  project_id bigint NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  camp_id bigint NOT NULL REFERENCES camps(id),
  PRIMARY KEY (project_id, camp_id)
);

-- ---------- Distributions ----------
CREATE TABLE assistance_types (
  id smallserial PRIMARY KEY, name_ar text NOT NULL, name_en text, is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE distributions (
  id bigserial PRIMARY KEY,
  title text NOT NULL,
  project_id bigint NOT NULL REFERENCES projects(id),
  camp_id bigint NOT NULL REFERENCES camps(id),
  assistance_type_id smallint NOT NULL REFERENCES assistance_types(id),
  mode distribution_mode NOT NULL DEFAULT 'names_only',
  planned_on date NOT NULL,
  responsible_team text,
  status distribution_status NOT NULL DEFAULT 'scheduled',
  notes text,
  created_by bigint NOT NULL REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE distribution_items (
  id bigserial PRIMARY KEY,
  distribution_id bigint NOT NULL REFERENCES distributions(id) ON DELETE CASCADE,
  item_name text NOT NULL,
  quantity_per_family numeric(12,2) NOT NULL CHECK (quantity_per_family > 0),
  unit text
);
CREATE TABLE distribution_beneficiaries (
  id bigserial PRIMARY KEY,
  distribution_id bigint NOT NULL REFERENCES distributions(id) ON DELETE CASCADE,
  family_id bigint NOT NULL REFERENCES families(id),
  received boolean NOT NULL DEFAULT false,
  received_at timestamptz,
  received_by_user bigint REFERENCES users(id),       -- officer who recorded the receipt
  id_verified boolean NOT NULL DEFAULT false,         -- receipt confirmed by ID number match
  notes text,
  UNIQUE (distribution_id, family_id),                -- one family once per activity
  CHECK (NOT received OR (id_verified AND received_at IS NOT NULL AND received_by_user IS NOT NULL))
);
CREATE INDEX dist_ben_family_idx ON distribution_beneficiaries (family_id);

-- ---------- Audit ----------
CREATE TABLE audit_logs (
  id bigserial PRIMARY KEY,
  user_id bigint REFERENCES users(id),
  action text NOT NULL,                               -- create, update, approve, export, login, ...
  entity text NOT NULL, entity_id bigint,
  details jsonb,
  ip inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_entity_idx ON audit_logs (entity, entity_id);
CREATE INDEX audit_user_idx ON audit_logs (user_id, created_at);

-- ---------- Rules enforced in the database ----------
-- 1) Moving a family between camps writes a history row.
CREATE FUNCTION trg_family_camp_move() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO family_camp_history (family_id, from_camp_id, to_camp_id, recorded_by)
    VALUES (NEW.id, NULL, NEW.current_camp_id, NEW.created_by);
  ELSIF NEW.current_camp_id IS DISTINCT FROM OLD.current_camp_id THEN
    INSERT INTO family_camp_history (family_id, from_camp_id, to_camp_id)
    VALUES (NEW.id, OLD.current_camp_id, NEW.current_camp_id);
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER families_camp_move_ins AFTER INSERT ON families FOR EACH ROW EXECUTE FUNCTION trg_family_camp_move();
CREATE FUNCTION trg_family_touch() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END $$;
CREATE TRIGGER families_camp_move_upd BEFORE UPDATE ON families FOR EACH ROW EXECUTE FUNCTION trg_family_camp_move();

-- 2) Only an approved family can be a beneficiary.
CREATE FUNCTION trg_beneficiary_family_approved() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF (SELECT status FROM families WHERE id = NEW.family_id) <> 'approved' THEN
    RAISE EXCEPTION 'family % is not approved', NEW.family_id USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER beneficiary_family_approved BEFORE INSERT ON distribution_beneficiaries
  FOR EACH ROW EXECUTE FUNCTION trg_beneficiary_family_approved();

-- ---------- Computed counts (never stored) ----------
CREATE VIEW v_camp_stats AS
SELECT c.id AS camp_id, c.code, c.name,
       count(DISTINCT f.id) AS families_count,
       count(m.id) AS members_count
FROM camps c
LEFT JOIN families f ON f.current_camp_id = c.id AND f.status <> 'archived'
LEFT JOIN family_members m ON m.family_id = f.id
GROUP BY c.id;
CREATE VIEW v_project_stats AS
SELECT p.id AS project_id, p.code, p.name,
       count(DISTINCT d.id) AS distributions_count,
       count(DISTINCT db.family_id) FILTER (WHERE db.received) AS families_served
FROM projects p
LEFT JOIN distributions d ON d.project_id = p.id
LEFT JOIN distribution_beneficiaries db ON db.distribution_id = d.id
GROUP BY p.id;
