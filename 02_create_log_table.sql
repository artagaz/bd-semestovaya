-- 02_create_log_table.sql
-- Структура данных для логирования операций

DROP TABLE operation_log PURGE;

CREATE TABLE operation_log (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name      VARCHAR2(50) NOT NULL,
    operation_type  VARCHAR2(10) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'DELETE')),
    operation_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    record_pk       VARCHAR2(100) NOT NULL,
    old_data        CLOB,
    new_data        CLOB,
    is_undone       CHAR(1) DEFAULT 'N' CHECK (is_undone IN ('Y', 'N'))
);

COMMIT;
