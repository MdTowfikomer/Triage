BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "inbox_items" (
    "id" bigserial PRIMARY KEY,
    "userId" uuid NOT NULL,
    "type" text NOT NULL,
    "title" text NOT NULL,
    "body" text,
    "tags" json,
    "priority" text,
    "emoji" text,
    "dueDate" timestamp without time zone,
    "redactedTranscript" text NOT NULL,
    "isCompleted" boolean NOT NULL,
    "completedAt" timestamp without time zone,
    "confidence" double precision,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "inbox_user_idx" ON "inbox_items" USING btree ("userId");
CREATE INDEX "inbox_type_idx" ON "inbox_items" USING btree ("type");
CREATE INDEX "inbox_created_idx" ON "inbox_items" USING btree ("createdAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "recordings" (
    "id" bigserial PRIMARY KEY,
    "inboxItemId" bigint NOT NULL,
    "storageUrl" text NOT NULL,
    "durationMs" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "recording_item_unique" ON "recordings" USING btree ("inboxItemId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "reminders" (
    "id" bigserial PRIMARY KEY,
    "inboxItemId" bigint NOT NULL,
    "triggerAt" timestamp without time zone NOT NULL,
    "recurring" text NOT NULL,
    "isFired" boolean NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "reminder_item_unique" ON "reminders" USING btree ("inboxItemId");
CREATE INDEX "reminder_trigger_idx" ON "reminders" USING btree ("triggerAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "inbox_items"
    ADD CONSTRAINT "inbox_items_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "recordings"
    ADD CONSTRAINT "recordings_fk_0"
    FOREIGN KEY("inboxItemId")
    REFERENCES "inbox_items"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "reminders"
    ADD CONSTRAINT "reminders_fk_0"
    FOREIGN KEY("inboxItemId")
    REFERENCES "inbox_items"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR triage
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('triage', '20261007180932480', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261007180932480', "timestamp" = now();

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
