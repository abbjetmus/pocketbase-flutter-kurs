-- =====================================================================
-- seed.sql – Föreningsappen (modul 01 – Databaser)
--
-- Skapar tabellerna apartments, users, resources, bookings och posts
-- och fyller dem med exempeldata. Skriptet är skrivet för SQLite.
--
-- Kör så här:
--   sqlite3 forening.db < seed.sql        (skapar/återställer en fil)
--   sqlite3 forening.db                    (öppna sedan databasen)
--
-- Skriptet kan köras flera gånger: det tar bort tabellerna först.
-- Alla tider lagras som text i UTC, format 'YYYY-MM-DD HH:MM:SS'.
-- =====================================================================

PRAGMA foreign_keys = ON;   -- SQLite kontrollerar inte främmande nycklar utan detta!

-- Ta bort i omvänd ordning (barn före föräldrar)
DROP VIEW  IF EXISTS upcoming_bookings;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS resources;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS apartments;

-- ---------------------------------------------------------------------
-- Tabeller
-- ---------------------------------------------------------------------

CREATE TABLE apartments (
    id        INTEGER PRIMARY KEY,                 -- auto-ökande id
    number    TEXT    NOT NULL UNIQUE,             -- t.ex. '1101'
    floor     INTEGER NOT NULL CHECK (floor >= 0),
    size_sqm  REAL    NOT NULL CHECK (size_sqm > 0)
);

CREATE TABLE users (
    id         INTEGER PRIMARY KEY,
    email      TEXT    NOT NULL UNIQUE,
    name       TEXT    NOT NULL,
    apartment  INTEGER REFERENCES apartments(id) ON DELETE SET NULL,
    role       TEXT    NOT NULL DEFAULT 'member'
                       CHECK (role IN ('member', 'board', 'admin')),
    created    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE resources (
    id           INTEGER PRIMARY KEY,
    name         TEXT    NOT NULL UNIQUE,
    description  TEXT,
    max_hours    INTEGER NOT NULL CHECK (max_hours BETWEEN 1 AND 24),
    active       INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
);

CREATE TABLE bookings (
    id        INTEGER PRIMARY KEY,
    resource  INTEGER NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
    user      INTEGER NOT NULL REFERENCES users(id)     ON DELETE CASCADE,
    "start"   TEXT    NOT NULL,
    "end"     TEXT    NOT NULL,
    note      TEXT,
    CHECK ("end" > "start")
);

CREATE TABLE posts (
    id         INTEGER PRIMARY KEY,
    title      TEXT    NOT NULL,
    body       TEXT    NOT NULL,
    author     INTEGER REFERENCES users(id) ON DELETE SET NULL,
    published  INTEGER NOT NULL DEFAULT 0 CHECK (published IN (0, 1)),
    created    TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Index på främmande nycklar och kolumner vi ofta filtrerar på
CREATE INDEX idx_users_apartment      ON users(apartment);
CREATE INDEX idx_bookings_user        ON bookings(user);
CREATE INDEX idx_bookings_resource_start ON bookings(resource, "start");
CREATE INDEX idx_posts_author         ON posts(author);

-- ---------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------

INSERT INTO apartments (id, number, floor, size_sqm) VALUES
    (1, '1001', 0, 34.5),
    (2, '1002', 0, 58.0),
    (3, '1101', 1, 72.0),
    (4, '1102', 1, 45.5),
    (5, '1201', 2, 72.0),
    (6, '1202', 2, 88.0),
    (7, '1301', 3, 104.0),
    (8, '1302', 3, 61.0);

INSERT INTO users (id, email, name, apartment, role, created) VALUES
    (1,  'anna@example.com',   'Anna Andersson',   3, 'board',  '2025-01-10 09:00:00'),
    (2,  'bertil@example.com', 'Bertil Berg',      3, 'member', '2025-01-12 18:30:00'),
    (3,  'cecilia@example.com','Cecilia Carlsson', 1, 'member', '2025-02-03 12:00:00'),
    (4,  'david@example.com',  'David Dahl',       2, 'board',  '2025-02-20 08:15:00'),
    (5,  'eva@example.com',    'Eva Ek',           5, 'member', '2025-03-01 10:00:00'),
    (6,  'fredrik@example.com','Fredrik Falk',     6, 'member', '2025-04-11 16:45:00'),
    (7,  'gunilla@example.com','Gunilla Gran',     7, 'admin',  '2025-04-11 17:00:00'),
    (8,  'hassan@example.com', 'Hassan Haddad',    7, 'member', '2025-06-23 20:10:00'),
    (9,  'ida@example.com',    'Ida Isaksson',     8, 'member', '2025-09-05 11:30:00'),
    (10, 'johan@example.com',  'Johan Jönsson',    NULL, 'member', '2026-01-15 14:00:00');
-- Johan har ännu ingen lägenhet kopplad (t.ex. nyinflyttad, ej registrerad).
-- Lägenhet 4 (1102) har ingen registrerad medlem.

INSERT INTO resources (id, name, description, max_hours, active) VALUES
    (1, 'Tvättstuga 1', 'Källaren, hus A. Två maskiner och en torktumlare.', 3, 1),
    (2, 'Tvättstuga 2', 'Källaren, hus B. Tre maskiner och torkskåp.',       3, 1),
    (3, 'Festlokalen',  'Plan 0. Plats för 30 personer, kök finns.',         12, 1),
    (4, 'Bastun',       'Stängd för renovering.',                            2, 0);

INSERT INTO bookings (id, resource, user, "start", "end", note) VALUES
    (1,  1, 1, '2026-10-12 07:00:00', '2026-10-12 10:00:00', NULL),
    (2,  1, 3, '2026-10-12 10:00:00', '2026-10-12 13:00:00', 'Mycket tvätt'),
    (3,  2, 5, '2026-10-12 16:00:00', '2026-10-12 19:00:00', NULL),
    (4,  3, 4, '2026-10-17 15:00:00', '2026-10-17 23:00:00', '40-årsfest'),
    (5,  1, 2, '2026-10-13 07:00:00', '2026-10-13 10:00:00', NULL),
    (6,  2, 6, '2026-10-13 10:00:00', '2026-10-13 13:00:00', NULL),
    (7,  1, 1, '2026-10-14 16:00:00', '2026-10-14 19:00:00', NULL),
    (8,  2, 8, '2026-10-14 07:00:00', '2026-10-14 10:00:00', NULL),
    (9,  3, 9, '2026-10-24 12:00:00', '2026-10-24 22:00:00', 'Barnkalas'),
    (10, 1, 5, '2026-10-15 13:00:00', '2026-10-15 16:00:00', NULL),
    (11, 2, 3, '2026-10-15 16:00:00', '2026-10-15 19:00:00', NULL),
    (12, 1, 7, '2026-10-16 07:00:00', '2026-10-16 10:00:00', NULL),
    (13, 3, 1, '2026-11-07 14:00:00', '2026-11-07 20:00:00', 'Föreningsstämma'),
    (14, 1, 1, '2026-09-28 07:00:00', '2026-09-28 10:00:00', NULL),
    (15, 2, 2, '2026-09-30 16:00:00', '2026-09-30 19:00:00', NULL);

INSERT INTO posts (id, title, body, author, published, created) VALUES
    (1, 'Välkommen till nya appen!',
        'Nu kan ni boka tvättstuga och festlokal direkt i mobilen.', 1, 1, '2026-09-01 08:00:00'),
    (2, 'Städdag 18 oktober',
        'Vi ses på gården kl 10. Föreningen bjuder på fika.',        4, 1, '2026-09-20 19:00:00'),
    (3, 'Bastun stängd',
        'Bastun renoveras under hösten. Vi återkommer med datum.',   7, 1, '2026-09-25 12:00:00'),
    (4, 'Kallelse till föreningsstämma',
        'Stämman hålls 7 november kl 14 i festlokalen.',             1, 1, '2026-10-01 09:00:00'),
    (5, 'Utkast: nya trivselregler',
        'Förslag på nya regler för tvättstugan. Ej klart.',          4, 0, '2026-10-05 21:00:00'),
    (6, 'Cykelrensning',
        'Omärkta cyklar i cykelrummet tas bort 1 november.',         7, 1, '2026-10-06 07:30:00');

-- En vy: kommande bokningar med namn i stället för id
CREATE VIEW upcoming_bookings AS
SELECT b.id,
       r.name  AS resource_name,
       u.name  AS user_name,
       b."start",
       b."end"
FROM bookings b
JOIN resources r ON r.id = b.resource
JOIN users     u ON u.id = b.user
WHERE b."start" >= '2026-10-12 00:00:00'
ORDER BY b."start";
