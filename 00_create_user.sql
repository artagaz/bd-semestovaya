-- ============================================================
-- 00_create_user.sql
-- Создание пользователя для семестровой работы
-- Выполнять под SYS / SYSTEM / SYSDBA
-- ============================================================

DROP USER student CASCADE;

CREATE USER student IDENTIFIED BY 123456
DEFAULT TABLESPACE USERS
QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE SEQUENCE,
      CREATE TRIGGER,
      CREATE PROCEDURE,
      CREATE VIEW,
      CREATE TYPE,
      CREATE SYNONYM
TO student;

-- Для работы JSON_OBJECT (Oracle 12c+)
GRANT EXECUTE ON SYS.DBMS_SQL TO student;

COMMIT;
