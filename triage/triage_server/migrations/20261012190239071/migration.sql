BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "device_registrations" (
    "id" bigserial PRIMARY KEY,
    "deviceId" text NOT NULL,
    "userId" uuid NOT NULL,
    "deviceToken" text NOT NULL,
    "deviceName" text,
    "registeredAt" timestamp without time zone NOT NULL,
    "lastSeenAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "device_registration_device_id_unique_idx" ON "device_registrations" USING btree ("deviceId");
CREATE INDEX "device_registration_token_idx" ON "device_registrations" USING btree ("deviceToken");
CREATE INDEX "device_registration_user_idx" ON "device_registrations" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "voice_command_logs" (
    "id" bigserial PRIMARY KEY,
    "eventId" text NOT NULL,
    "deviceId" text NOT NULL,
    "intent" text NOT NULL,
    "actionTarget" text,
    "resultType" text NOT NULL,
    "executionLatencyMs" bigint,
    "executedOffline" boolean NOT NULL,
    "syncedAt" timestamp without time zone NOT NULL,
    "transcript" text
);

-- Indexes
CREATE UNIQUE INDEX "voice_command_event_id_unique_idx" ON "voice_command_logs" USING btree ("eventId");
CREATE INDEX "voice_command_device_idx" ON "voice_command_logs" USING btree ("deviceId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "device_registrations"
    ADD CONSTRAINT "device_registrations_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR triage
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('triage', '20261012190239071', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012190239071', "timestamp" = now();

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
