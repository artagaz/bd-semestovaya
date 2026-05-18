-- 06_test.sql
-- Тесты

SET SERVEROUTPUT ON;

-- ------------------------------------------------------------
-- 1. Тест CRUD + автологирование (suppliers)
-- ------------------------------------------------------------
DECLARE
    v_new_id suppliers.id%TYPE;
    v_cursor SYS_REFCURSOR;
    v_log_id operation_log.log_id%TYPE;
    v_tn     operation_log.table_name%TYPE;
    v_ot     operation_log.operation_type%TYPE;
    v_pk     operation_log.record_pk%TYPE;
    v_und    operation_log.is_undone%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 1: CRUD suppliers + logging ===');

    -- INSERT
    pkg_entity_crud.add_supplier('Test Supplier', 'Diler', 'test@test.com', 'Y', 'CT-TEST-99', v_new_id);
    DBMS_OUTPUT.PUT_LINE('Inserted supplier id=' || v_new_id);

    -- UPDATE
    pkg_entity_crud.upd_supplier(v_new_id, 'Test Supplier Updated', 'Proizvoditel', 'new@test.com', 'N', NULL);
    DBMS_OUTPUT.PUT_LINE('Updated supplier id=' || v_new_id);

    -- DELETE
    pkg_entity_crud.del_supplier(v_new_id);
    DBMS_OUTPUT.PUT_LINE('Deleted supplier id=' || v_new_id);

    -- Проверим лог
    OPEN v_cursor FOR
        SELECT log_id, table_name, operation_type, record_pk, is_undone
        FROM operation_log
        WHERE table_name = 'SUPPLIERS'
        ORDER BY log_id DESC
        FETCH FIRST 3 ROWS ONLY;

    LOOP
        FETCH v_cursor INTO v_log_id, v_tn, v_ot, v_pk, v_und;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('LOG: id=' || v_log_id || ' table=' || v_tn ||
                             ' op=' || v_ot || ' pk=' || v_pk || ' undone=' || v_und);
    END LOOP;
    CLOSE v_cursor;
END;
/

-- ------------------------------------------------------------
-- 2. Тест CRUD + автологирование (products)
-- ------------------------------------------------------------
DECLARE
    v_new_id products.id%TYPE;
    v_cursor SYS_REFCURSOR;
    v_log_id operation_log.log_id%TYPE;
    v_tn     operation_log.table_name%TYPE;
    v_ot     operation_log.operation_type%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 2: CRUD products + logging ===');

    pkg_entity_crud.add_product('Test Product', 'TEST-ARTICLE-999', v_new_id);
    DBMS_OUTPUT.PUT_LINE('Inserted product id=' || v_new_id);

    pkg_entity_crud.upd_product(v_new_id, 'Test Product Updated', 'TEST-ARTICLE-999-U');
    DBMS_OUTPUT.PUT_LINE('Updated product id=' || v_new_id);

    pkg_entity_crud.del_product(v_new_id);
    DBMS_OUTPUT.PUT_LINE('Deleted product id=' || v_new_id);

    OPEN v_cursor FOR
        SELECT log_id, table_name, operation_type
        FROM operation_log
        WHERE table_name = 'PRODUCTS'
        ORDER BY log_id DESC
        FETCH FIRST 3 ROWS ONLY;

    LOOP
        FETCH v_cursor INTO v_log_id, v_tn, v_ot;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('LOG: id=' || v_log_id || ' table=' || v_tn || ' op=' || v_ot);
    END LOOP;
    CLOSE v_cursor;
END;
/

-- ------------------------------------------------------------
-- 3. Тест CRUD + автологирование (purchase_orders)
-- ------------------------------------------------------------
DECLARE
    v_new_id purchase_orders.id%TYPE;
    v_cursor SYS_REFCURSOR;
    v_log_id operation_log.log_id%TYPE;
    v_tn     operation_log.table_name%TYPE;
    v_ot     operation_log.operation_type%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 3: CRUD purchase_orders + logging ===');

    pkg_entity_crud.add_purchase_order(1, DATE '2025-12-20', v_new_id);
    DBMS_OUTPUT.PUT_LINE('Inserted order id=' || v_new_id);

    pkg_entity_crud.upd_purchase_order(v_new_id, 2, DATE '2025-12-21');
    DBMS_OUTPUT.PUT_LINE('Updated order id=' || v_new_id);

    pkg_entity_crud.del_purchase_order(v_new_id);
    DBMS_OUTPUT.PUT_LINE('Deleted order id=' || v_new_id);

    OPEN v_cursor FOR
        SELECT log_id, table_name, operation_type
        FROM operation_log
        WHERE table_name = 'PURCHASE_ORDERS'
        ORDER BY log_id DESC
        FETCH FIRST 3 ROWS ONLY;

    LOOP
        FETCH v_cursor INTO v_log_id, v_tn, v_ot;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('LOG: id=' || v_log_id || ' table=' || v_tn || ' op=' || v_ot);
    END LOOP;
    CLOSE v_cursor;
END;
/

-- ------------------------------------------------------------
-- 4. Тест просмотра лога (view_log)
-- ------------------------------------------------------------
DECLARE
    v_cursor SYS_REFCURSOR;
    v_log_id operation_log.log_id%TYPE;
    v_tn     operation_log.table_name%TYPE;
    v_ot     operation_log.operation_type%TYPE;
    v_date   operation_log.operation_date%TYPE;
    v_pk     operation_log.record_pk%TYPE;
    v_old    operation_log.old_data%TYPE;
    v_new    operation_log.new_data%TYPE;
    v_und    operation_log.is_undone%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 4: view_log (last 10 rows) ===');

    pkg_log_manager.view_log(
        p_start_date    => NULL,
        p_end_date      => NULL,
        p_operation_type=> NULL,
        p_cursor        => v_cursor
    );

    LOOP
        FETCH v_cursor INTO v_log_id, v_tn, v_ot, v_date, v_pk, v_old, v_new, v_und;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('LOG: id=' || v_log_id || ' table=' || v_tn ||
                             ' op=' || v_ot || ' date=' || v_date ||
                             ' pk=' || v_pk || ' undone=' || v_und);
    END LOOP;
    CLOSE v_cursor;
END;
/

-- ------------------------------------------------------------
-- 5. Тест отмены операции (undo)
-- ------------------------------------------------------------
DECLARE
    v_sup_id suppliers.id%TYPE;
    v_log_id operation_log.log_id%TYPE;
    v_cnt    NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 5: undo_operation ===');

    -- Создаём поставщика, запоминаем log_id INSERT
    pkg_entity_crud.add_supplier('Undo Test', 'Diler', 'undo@test.com', 'Y', 'CT-UNDO-01', v_sup_id);

    BEGIN
        SELECT log_id INTO v_log_id
        FROM operation_log
        WHERE table_name = 'SUPPLIERS' AND operation_type = 'INSERT'
        ORDER BY log_id DESC FETCH FIRST 1 ROW ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: operation_log is empty — check triggers');
            RAISE;
    END;

    DBMS_OUTPUT.PUT_LINE('Created supplier id=' || v_sup_id || ', log_id=' || v_log_id);

    -- Проверяем, что он есть
    SELECT COUNT(*) INTO v_cnt FROM suppliers WHERE id = v_sup_id;
    DBMS_OUTPUT.PUT_LINE('Count before undo=' || v_cnt);

    -- Отменяем INSERT → DELETE
    pkg_log_manager.undo_operation(v_log_id);

    SELECT COUNT(*) INTO v_cnt FROM suppliers WHERE id = v_sup_id;
    DBMS_OUTPUT.PUT_LINE('Count after undo=' || v_cnt || ' (expected 0)');
END;
/

-- ------------------------------------------------------------
-- 6. Тест сводного отчёта (get_report)
-- ------------------------------------------------------------
DECLARE
    v_cursor SYS_REFCURSOR;
    v_tn     operation_log.table_name%TYPE;
    v_ot     operation_log.operation_type%TYPE;
    v_cnt    NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== TEST 6: get_report (sort by table_name, then count) ===');

    v_cursor := pkg_log_manager.get_report(p_sort1 => TRUE, p_sort2 => FALSE, p_sort3 => TRUE);

    LOOP
        FETCH v_cursor INTO v_tn, v_ot, v_cnt;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('REPORT: table=' || v_tn || ' op=' || v_ot || ' count=' || v_cnt);
    END LOOP;
    CLOSE v_cursor;
END;
/

COMMIT;
