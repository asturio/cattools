/* Create Database */

/* Setup Passwort */

/* Create working user */

/* Drop Tables */
DROP TABLE message IF EXISTS;
DROP TABLE person IF EXISTS;
DROP TABLE groups IF EXISTS;
DROP TABLE language IF EXISTS;

/* Create Tables */
CREATE TABLE language (
    language_id INTEGER IDENTITY,
    name        VARCHAR(40) NOT NULL,
    iso_code    VARCHAR(5)
);

CREATE TABLE groups (
    group_id    INTEGER IDENTITY,
    name        VARCHAR(40) NOT NULL,
    description VARCHAR(512)
);

CREATE TABLE person (
    sex         SMALLINT,
    firstname   VARCHAR(80),
    lastname    VARCHAR(80),
    birthdate   DATE,
    email       VARCHAR(128),
    language_id INTEGER,
    group_id    INTEGER,
    last_greet  DATE,
    FOREIGN KEY (language_id) REFERENCES language(language_id),
    FOREIGN KEY (group_id) REFERENCES groups(group_id)
);

CREATE TABLE message (
    id          INTEGER IDENTITY,
    message     VARCHAR(512),
    language_id INTEGER,
    group_id    INTEGER,
    FOREIGN KEY (language_id) REFERENCES language(language_id),
    FOREIGN KEY (group_id) REFERENCES groups(group_id)
);
