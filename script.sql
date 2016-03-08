-- Cleaning --

--DROP TABLE "user" CASCADE;
--DROP TABLE command CASCADE;


-- Table creation --
CREATE TABLE "user" (
    id      serial primary key,
    name    character varying
);

CREATE TABLE command (
    id      serial primary key,
    user_id integer,
    time    timestamp,
    log     character varying
);

CREATE TABLE command_post_2010 (
    CHECK (time >= DATE '2010-01-01')
) INHERITS (command);

CREATE TABLE command_pre_2010 (
    CHECK (time < DATE '2010-01-01')
) INHERITS (command);


-- Functions --

--manually putting the id so that each table has its own contiguous ids
CREATE OR REPLACE FUNCTION reroute_insert()
    RETURNS trigger AS $$
BEGIN
    IF (NEW.time < DATE '2010-01-01') THEN
        INSERT INTO command_pre_2010 VALUES (
            (SELECT coalesce(max(id), 0) FROM command_pre_2010)+1, NEW.user_id, NEW.time, NEW.log);
    ELSE
        INSERT INTO command_post_2010 VALUES (
            (SELECT coalesce(max(id), 0) FROM command_post_2010)+1, NEW.user_id, NEW.time, NEW.log);
    END IF;

    RETURN null;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION reroute_delete ()
    RETURNS trigger AS $$
BEGIN
    IF (OLD.time < DATE '2010-01-01') THEN
        DELETE FROM command_pre_2010 WHERE id=OLD.id;
    ELSE
        DELETE FROM command_post_2010 WHERE id=OLD.id;
    END IF;

    RETURN null;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION reroute_update ()
    RETURNS trigger AS $$
BEGIN

    IF OLD IS DISTINCT FROM NEW THEN -- Avoid unnecessary updates
        IF (OLD.time < DATE '2010-01-01') THEN
            DELETE FROM command_pre_2010 WHERE id=OLD.id;
        ELSE
            DELETE FROM command_post_2010 WHERE id=OLD.id;
        END IF;

        INSERT INTO command VALUES (NEW.*);

    END IF;

    RETURN null;
END;
$$ LANGUAGE plpgsql;


-- Triggers --

CREATE TRIGGER trigger_reroute_insert BEFORE INSERT ON command
    FOR EACH ROW EXECUTE PROCEDURE reroute_insert();
CREATE TRIGGER trigger_reroute_delete BEFORE DELETE ON command
    FOR EACH ROW EXECUTE PROCEDURE reroute_delete();
CREATE TRIGGER trigger_reroute_update BEFORE UPDATE ON command
    FOR EACH ROW EXECUTE PROCEDURE reroute_update();


-- Actions --

INSERT INTO "user" (id, name) VALUES
    (1, 'charly'),
    (2, 'root'),
    (3, 'test'),
    (4, 'sales'),
    (5, 'random') ;

-- the 'g' only serves for outer dependence and forces a new random each time
INSERT INTO command (user_id, time, log)
    SELECT
        (SELECT id from "user" WHERE g=g ORDER BY RANDOM() limit 1),
        (NOW() - '1 year'::INTERVAL * ROUND(RANDOM() * 12)), -- 2004 to 2016
        ''
    FROM generate_series(1, 1000) g;