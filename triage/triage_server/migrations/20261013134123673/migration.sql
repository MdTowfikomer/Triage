BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "device_telemetry" (
    "id" bigserial PRIMARY KEY,
    "deviceId" text NOT NULL,
    "batteryLevel" bigint NOT NULL,
    "isCharging" boolean NOT NULL,
    "volumeLevel" double precision NOT NULL,
    "brightnessLevel" double precision NOT NULL,
    "dndEnabled" boolean NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "device_telemetry_device_id_unique_idx" ON "device_telemetry" USING btree ("deviceId");


--
-- MIGRATION VERSION FOR triage
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('triage', '20261013134123673', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261013134123673', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
