/* Create Database */

/* Setup Passwort */

/* Create working user */

/* Create Tables */
CREATE TABLE language (
    language_id INTEGER IDENTITY,
    iso_code    VARCHAR(5),
    name        VARCHAR(40)
);

CREATE TABLE groups (
    group_id    INTEGER IDENTITY,
    name        VARCHAR(40),
    description VARCHAR(512)
);

CREATE TABLE person (
    sex         SMALLINT,
    firstname   VARCHAR(80),
    lastname    VARCHAR(80),
    birthdate   DATE,
    email       VARCHAR(128),
    fk_language INTEGER,
    fk_group    INTEGER,
    FOREIGN KEY fk_language ON language(language_id),
    FOREIGN KEY fk_group ON groups(group_id)
);
