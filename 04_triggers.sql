-- 04_triggers.sql
-- Триггеры

CREATE OR REPLACE TRIGGER trg_log_suppliers
AFTER INSERT OR UPDATE OR DELETE ON suppliers
FOR EACH ROW
DECLARE
    v_old CLOB; v_new CLOB; v_op VARCHAR2(10); v_pk NUMBER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'CLIENT_INFO') = 'SKIP_LOGGING' THEN RETURN; END IF;

    IF INSERTING THEN
        v_op := 'INSERT'; v_pk := :NEW.id;
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'name' VALUE :NEW.name,'category' VALUE :NEW.category,'contact_info' VALUE :NEW.contact_info,'has_guarantee' VALUE :NEW.has_guarantee,'contract_id' VALUE :NEW.contract_id);
    ELSIF UPDATING THEN
        v_op := 'UPDATE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'name' VALUE :OLD.name,'category' VALUE :OLD.category,'contact_info' VALUE :OLD.contact_info,'has_guarantee' VALUE :OLD.has_guarantee,'contract_id' VALUE :OLD.contract_id);
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'name' VALUE :NEW.name,'category' VALUE :NEW.category,'contact_info' VALUE :NEW.contact_info,'has_guarantee' VALUE :NEW.has_guarantee,'contract_id' VALUE :NEW.contract_id);
    ELSE
        v_op := 'DELETE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'name' VALUE :OLD.name,'category' VALUE :OLD.category,'contact_info' VALUE :OLD.contact_info,'has_guarantee' VALUE :OLD.has_guarantee,'contract_id' VALUE :OLD.contract_id);
    END IF;

    INSERT INTO operation_log (table_name, operation_type, record_pk, old_data, new_data)
    VALUES ('SUPPLIERS', v_op, TO_CHAR(v_pk), v_old, v_new);
END;
/

CREATE OR REPLACE TRIGGER trg_log_products
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW
DECLARE
    v_old CLOB; v_new CLOB; v_op VARCHAR2(10); v_pk NUMBER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'CLIENT_INFO') = 'SKIP_LOGGING' THEN RETURN; END IF;

    IF INSERTING THEN
        v_op := 'INSERT'; v_pk := :NEW.id;
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'name' VALUE :NEW.name,'article' VALUE :NEW.article);
    ELSIF UPDATING THEN
        v_op := 'UPDATE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'name' VALUE :OLD.name,'article' VALUE :OLD.article);
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'name' VALUE :NEW.name,'article' VALUE :NEW.article);
    ELSE
        v_op := 'DELETE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'name' VALUE :OLD.name,'article' VALUE :OLD.article);
    END IF;

    INSERT INTO operation_log (table_name, operation_type, record_pk, old_data, new_data)
    VALUES ('PRODUCTS', v_op, TO_CHAR(v_pk), v_old, v_new);
END;
/

CREATE OR REPLACE TRIGGER trg_log_purchase_orders
AFTER INSERT OR UPDATE OR DELETE ON purchase_orders
FOR EACH ROW
DECLARE
    v_old CLOB; v_new CLOB; v_op VARCHAR2(10); v_pk NUMBER;
BEGIN
    IF SYS_CONTEXT('USERENV', 'CLIENT_INFO') = 'SKIP_LOGGING' THEN RETURN; END IF;

    IF INSERTING THEN
        v_op := 'INSERT'; v_pk := :NEW.id;
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'supplier_id' VALUE :NEW.supplier_id,'order_date' VALUE TO_CHAR(:NEW.order_date,'YYYY-MM-DD'));
    ELSIF UPDATING THEN
        v_op := 'UPDATE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'supplier_id' VALUE :OLD.supplier_id,'order_date' VALUE TO_CHAR(:OLD.order_date,'YYYY-MM-DD'));
        v_new := JSON_OBJECT('id' VALUE :NEW.id,'supplier_id' VALUE :NEW.supplier_id,'order_date' VALUE TO_CHAR(:NEW.order_date,'YYYY-MM-DD'));
    ELSE
        v_op := 'DELETE'; v_pk := :OLD.id;
        v_old := JSON_OBJECT('id' VALUE :OLD.id,'supplier_id' VALUE :OLD.supplier_id,'order_date' VALUE TO_CHAR(:OLD.order_date,'YYYY-MM-DD'));
    END IF;

    INSERT INTO operation_log (table_name, operation_type, record_pk, old_data, new_data)
    VALUES ('PURCHASE_ORDERS', v_op, TO_CHAR(v_pk), v_old, v_new);
END;
/
