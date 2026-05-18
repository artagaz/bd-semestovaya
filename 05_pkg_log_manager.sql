-- 05_pkg_log_manager.sql
-- Пакет: просмотр лога, отмена операции, сводный отчёт

CREATE OR REPLACE PACKAGE pkg_log_manager AS
    PROCEDURE view_log(
        p_start_date     IN TIMESTAMP DEFAULT NULL,
        p_end_date       IN TIMESTAMP DEFAULT NULL,
        p_operation_type IN VARCHAR2  DEFAULT NULL,
        p_cursor         OUT SYS_REFCURSOR
    );

    PROCEDURE undo_operation(p_log_id IN NUMBER);

    FUNCTION get_report(
        p_sort1 IN BOOLEAN DEFAULT FALSE,
        p_sort2 IN BOOLEAN DEFAULT FALSE,
        p_sort3 IN BOOLEAN DEFAULT FALSE
    ) RETURN SYS_REFCURSOR;

END pkg_log_manager;
/

CREATE OR REPLACE PACKAGE BODY pkg_log_manager AS

    PROCEDURE view_log(
        p_start_date     IN TIMESTAMP DEFAULT NULL,
        p_end_date       IN TIMESTAMP DEFAULT NULL,
        p_operation_type IN VARCHAR2  DEFAULT NULL,
        p_cursor         OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT log_id, table_name, operation_type, operation_date,
                   record_pk, old_data, new_data, is_undone
            FROM operation_log
            WHERE (p_operation_type IS NULL OR operation_type = p_operation_type)
              AND (p_start_date IS NULL OR operation_date >= p_start_date)
              AND (p_end_date IS NULL OR operation_date <= p_end_date)
            ORDER BY log_id DESC;
    END view_log;

    PROCEDURE undo_operation(p_log_id IN NUMBER) IS
        v_rec operation_log%ROWTYPE;
    BEGIN
        SELECT * INTO v_rec FROM operation_log WHERE log_id = p_log_id;
        -- уже отменена
        IF v_rec.is_undone = 'Y' THEN
            RAISE_APPLICATION_ERROR(-20051, 'Operation already undone');
        END IF;

        -- не писать лог
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO('SKIP_LOGGING');

        CASE v_rec.operation_type
            WHEN 'INSERT' THEN
                EXECUTE IMMEDIATE 'DELETE FROM ' || v_rec.table_name || ' WHERE id = :pk'
                    USING TO_NUMBER(v_rec.record_pk);

            WHEN 'DELETE' THEN
                CASE v_rec.table_name
                    WHEN 'SUPPLIERS' THEN
                        INSERT INTO suppliers (id, name, category, contact_info, has_guarantee, contract_id)
                        VALUES (JSON_VALUE(v_rec.old_data,'$.id' RETURNING NUMBER),
                                JSON_VALUE(v_rec.old_data,'$.name' RETURNING VARCHAR2),
                                JSON_VALUE(v_rec.old_data,'$.category' RETURNING VARCHAR2),
                                JSON_VALUE(v_rec.old_data,'$.contact_info' RETURNING VARCHAR2),
                                JSON_VALUE(v_rec.old_data,'$.has_guarantee' RETURNING VARCHAR2),
                                JSON_VALUE(v_rec.old_data,'$.contract_id' RETURNING VARCHAR2));
                    WHEN 'PRODUCTS' THEN
                        INSERT INTO products (id, name, article)
                        VALUES (JSON_VALUE(v_rec.old_data,'$.id' RETURNING NUMBER),
                                JSON_VALUE(v_rec.old_data,'$.name' RETURNING VARCHAR2),
                                JSON_VALUE(v_rec.old_data,'$.article' RETURNING VARCHAR2));
                    WHEN 'PURCHASE_ORDERS' THEN
                        INSERT INTO purchase_orders (id, supplier_id, order_date)
                        VALUES (JSON_VALUE(v_rec.old_data,'$.id' RETURNING NUMBER),
                                JSON_VALUE(v_rec.old_data,'$.supplier_id' RETURNING NUMBER),
                                TO_DATE(JSON_VALUE(v_rec.old_data,'$.order_date' RETURNING VARCHAR2),'YYYY-MM-DD'));
                END CASE;

            WHEN 'UPDATE' THEN
                CASE v_rec.table_name
                    WHEN 'SUPPLIERS' THEN
                        UPDATE suppliers SET
                            name = JSON_VALUE(v_rec.old_data,'$.name' RETURNING VARCHAR2),
                            category = JSON_VALUE(v_rec.old_data,'$.category' RETURNING VARCHAR2),
                            contact_info = JSON_VALUE(v_rec.old_data,'$.contact_info' RETURNING VARCHAR2),
                            has_guarantee = JSON_VALUE(v_rec.old_data,'$.has_guarantee' RETURNING VARCHAR2),
                            contract_id = JSON_VALUE(v_rec.old_data,'$.contract_id' RETURNING VARCHAR2)
                        WHERE id = TO_NUMBER(v_rec.record_pk);
                    WHEN 'PRODUCTS' THEN
                        UPDATE products SET
                            name = JSON_VALUE(v_rec.old_data,'$.name' RETURNING VARCHAR2),
                            article = JSON_VALUE(v_rec.old_data,'$.article' RETURNING VARCHAR2)
                        WHERE id = TO_NUMBER(v_rec.record_pk);
                    WHEN 'PURCHASE_ORDERS' THEN
                        UPDATE purchase_orders SET
                            supplier_id = JSON_VALUE(v_rec.old_data,'$.supplier_id' RETURNING NUMBER),
                            order_date = TO_DATE(JSON_VALUE(v_rec.old_data,'$.order_date' RETURNING VARCHAR2),'YYYY-MM-DD')
                        WHERE id = TO_NUMBER(v_rec.record_pk);
                END CASE;
        END CASE;

        UPDATE operation_log SET is_undone = 'Y' WHERE log_id = p_log_id;
        --писать логи
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
    -- другие ошибки
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL);
            RAISE;
    END undo_operation;

    FUNCTION get_report(
        p_sort1 IN BOOLEAN DEFAULT FALSE,
        p_sort2 IN BOOLEAN DEFAULT FALSE,
        p_sort3 IN BOOLEAN DEFAULT FALSE
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
        v_sql    VARCHAR2(1000);
        v_order  VARCHAR2(200) := '';
    BEGIN
        v_sql := 'SELECT table_name, operation_type, COUNT(*) AS op_count
                  FROM operation_log
                  GROUP BY table_name, operation_type';

        IF p_sort1 THEN v_order := v_order || 'table_name,'; END IF;
        IF p_sort2 THEN v_order := v_order || 'operation_type,'; END IF;
        IF p_sort3 THEN v_order := v_order || 'op_count DESC,'; END IF;

        IF v_order IS NOT NULL THEN
            v_sql := v_sql || ' ORDER BY ' || RTRIM(v_order, ',');
        END IF;

        OPEN v_cursor FOR v_sql;
        RETURN v_cursor;
    END get_report;

END pkg_log_manager;
/
