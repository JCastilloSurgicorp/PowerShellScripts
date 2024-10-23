CREATE PROCEDURE proc_audit_async

(@inserted XML, @deleted XML)

AS

BEGIN

    RETURN

END

GO

CREATE PROCEDURE proc_audit_async_callback

(@inserted XML, @deleted XML)

AS

BEGIN

    -- Creamos las tablas inserted y deleted. En este ejemplo no sería

    -- necesario materializarlas, pudiendo utilizar directamente la

    -- consulta en la inserción de auditoría posterior.

    SELECT tabla.fila.value('@id', 'INT') as id,

         tabla.fila.value('@data1', 'NVARCHAR(100)') as data1,

         tabla.fila.value('@data2', 'NVARCHAR(100)') as data2    

    INTO INSERTED

    FROM @inserted.nodes('/INSERTED') tabla(fila);

    

    SELECT tabla.fila.value('@id', 'INT') as id,

         tabla.fila.value('@data1', 'NVARCHAR(100)') as data1,

         tabla.fila.value('@data2', 'NVARCHAR(100)') as data2    

    INTO DELETED

    FROM @deleted.nodes('/DELETED') tabla(fila);

 

    -- Auditamos los cambios

    IF EXISTS (SELECT * FROM DELETED)

        INSERT INTO base_audit (tipo,id,data1,data2)

        SELECT 'D',* FROM DELETED

    IF EXISTS (SELECT * FROM INSERTED)

        INSERT INTO base_audit (tipo,id,data1,data2)

        SELECT 'I', * FROM INSERTED

END