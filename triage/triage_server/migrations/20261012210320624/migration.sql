BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "routine_schedules" (
    "id" bigserial PRIMARY KEY,
    "routineId" text NOT NULL,
    "deviceId" text NOT NULL,
    "userId" uuid NOT NULL,
    "name" text NOT NULL,
    "scheduledTime" timestamp without time zone NOT NULL,
    "stepsJson" text NOT NULL,
    "status" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "dispatchedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    "lastError" text
);

-- Indexes
CREATE UNIQUE INDEX "routine_schedule_routine_id_unique_idx" ON "routine_schedules" USING btree ("routineId");
CREATE INDEX "routine_schedule_device_idx" ON "routine_schedules" USING btree ("deviceId");
CREATE INDEX "routine_schedule_status_idx" ON "routine_schedules" USING btree ("status");
CREATE INDEX "routine_schedule_user_idx" ON "routine_schedules" USING btree ("userId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "routine_schedules"
    ADD CONSTRAINT "routine_schedules_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR triage
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('triage', '20261012210320624', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012210320624', "timestamp" = now();

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
