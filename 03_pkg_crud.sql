-- 03_pkg_crud.sql
-- Пакет CRUD

CREATE OR REPLACE PACKAGE pkg_entity_crud AS
    -- suppliers
    PROCEDURE add_supplier(p_name IN VARCHAR2, p_category IN VARCHAR2, p_contact_info IN VARCHAR2,
                           p_has_guarantee IN CHAR, p_contract_id IN VARCHAR2, p_new_id OUT NUMBER);
    PROCEDURE upd_supplier(p_id IN NUMBER, p_name IN VARCHAR2, p_category IN VARCHAR2, p_contact_info IN VARCHAR2,
                           p_has_guarantee IN CHAR, p_contract_id IN VARCHAR2);
    PROCEDURE del_supplier(p_id IN NUMBER);

    -- products
    PROCEDURE add_product(p_name IN VARCHAR2, p_article IN VARCHAR2, p_new_id OUT NUMBER);
    PROCEDURE upd_product(p_id IN NUMBER, p_name IN VARCHAR2, p_article IN VARCHAR2);
    PROCEDURE del_product(p_id IN NUMBER);

    -- purchase_orders
    PROCEDURE add_purchase_order(p_supplier_id IN NUMBER, p_order_date IN DATE, p_new_id OUT NUMBER);
    PROCEDURE upd_purchase_order(p_id IN NUMBER, p_supplier_id IN NUMBER, p_order_date IN DATE);
    PROCEDURE del_purchase_order(p_id IN NUMBER);
END pkg_entity_crud;
/

-- body ===================================================================================================================
CREATE OR REPLACE PACKAGE BODY pkg_entity_crud AS
-- Приватные хелперы --------------------------------------------------------------------------
    PROCEDURE assert_not_null(p_val IN VARCHAR2, p_name IN VARCHAR2) IS
    BEGIN
        IF p_val IS NULL THEN
            RAISE_APPLICATION_ERROR(-20001, p_name || ' is required');
        END IF;
    END;

    PROCEDURE assert_found(p_msg IN VARCHAR2) IS
    BEGIN
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, p_msg);
        END IF;
    END;

    PROCEDURE assert_supplier_exists(p_supplier_id IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_cnt NUMBER;
    BEGIN
        IF p_supplier_id IS NULL THEN RETURN; END IF;
        SELECT COUNT(*) INTO v_cnt FROM suppliers WHERE id = p_supplier_id;
        IF v_cnt = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Supplier does not exist');
        END IF;
    END;

-- SUPPLIERS -------------------------------------------------------------------------------------------------------
    PROCEDURE add_supplier(p_name IN VARCHAR2, p_category IN VARCHAR2, p_contact_info IN VARCHAR2,
                        p_has_guarantee IN CHAR, p_contract_id IN VARCHAR2, p_new_id OUT NUMBER) IS
    BEGIN
        assert_not_null(p_name, 'Name');
        INSERT INTO suppliers (name, category, contact_info, has_guarantee, contract_id)
        VALUES (p_name, p_category, p_contact_info, p_has_guarantee, p_contract_id)
        RETURNING id INTO p_new_id;
    END;

    PROCEDURE upd_supplier(p_id IN NUMBER, p_name IN VARCHAR2, p_category IN VARCHAR2, p_contact_info IN VARCHAR2,
                           p_has_guarantee IN CHAR, p_contract_id IN VARCHAR2) IS
    BEGIN
        UPDATE suppliers
        SET name = p_name, category = p_category, contact_info = p_contact_info,
            has_guarantee = p_has_guarantee, contract_id = p_contract_id
        WHERE id = p_id;
        assert_found('Supplier not found');
    END;

    PROCEDURE del_supplier(p_id IN NUMBER) IS
    BEGIN
        DELETE FROM suppliers WHERE id = p_id;
        assert_found('Supplier not found');
    END;

-- PRODUCTS -----------------------------------------------------------------------------------------------------------------
    PROCEDURE add_product(p_name IN VARCHAR2, p_article IN VARCHAR2, p_new_id OUT NUMBER) IS
    BEGIN
        assert_not_null(p_name, 'Name');
        assert_not_null(p_article, 'Article');
        INSERT INTO products (name, article) VALUES (p_name, p_article) RETURNING id INTO p_new_id;
    END;

    PROCEDURE upd_product(p_id IN NUMBER, p_name IN VARCHAR2, p_article IN VARCHAR2) IS
    BEGIN
        UPDATE products SET name = p_name, article = p_article WHERE id = p_id;
        assert_found('Product not found');
    END;

    PROCEDURE del_product(p_id IN NUMBER) IS
    BEGIN
        DELETE FROM products WHERE id = p_id;
        assert_found('Product not found');
    END;

-- PURCHASE_ORDERS -------------------------------------------------------------------------------------------------------------

    PROCEDURE add_purchase_order(p_supplier_id IN NUMBER, p_order_date IN DATE, p_new_id OUT NUMBER) IS
    BEGIN
        assert_not_null(TO_CHAR(p_supplier_id), 'Supplier');
        assert_not_null(TO_CHAR(p_order_date), 'Order date');
        assert_supplier_exists(p_supplier_id);
        INSERT INTO purchase_orders (supplier_id, order_date)
        VALUES (p_supplier_id, p_order_date) RETURNING id INTO p_new_id;
    END;

    PROCEDURE upd_purchase_order(p_id IN NUMBER, p_supplier_id IN NUMBER, p_order_date IN DATE) IS
    BEGIN
        assert_supplier_exists(p_supplier_id);
        UPDATE purchase_orders SET supplier_id = p_supplier_id, order_date = p_order_date WHERE id = p_id;
        assert_found('Purchase order not found');
    END;

    PROCEDURE del_purchase_order(p_id IN NUMBER) IS
    BEGIN
        DELETE FROM purchase_orders WHERE id = p_id;
        assert_found('Purchase order not found');
    END;

END pkg_entity_crud;
/
