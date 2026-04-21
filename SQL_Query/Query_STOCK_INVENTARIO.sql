SELECT * FROM [dbo].[SI_DEPOSITO] WHERE CODIGO_DEPOSITO = 'SG-C215-C'
SELECT * FROM [dbo].[SI_TIPOALMACEN]
SELECT * FROM [dbo].[SI_SECTOR]
SELECT * FROM [dbo].[SI_KITS_prod_id]
SELECT * FROM [dbo].[SI_KITS]
SELECT * FROM [dbo].[SI_TIPOPRODUCTO]
SELECT * FROM [dbo].[USR_PARINT]
SELECT * FROM [dbo].[USR_VTTVND]
SELECT * FROM [dbo].[USR_VTTENT]
SELECT * FROM [dbo].[USR_VTMCLH]
SELECT * FROM [dbo].[SI_UPDATE_AUDIT]


-- Consultas a descripcion de stock
SELECT * FROM [dbo].[SI_DESCRIPCION]
WHERE GUIA_REMISION is not NULL

-- Consultas a la tabla de stock_inventario
SELECT * FROM [dbo].[STOCK_INVENTARIO]
--WHERE OTROS is not NULL
WHERE USUARIO like '%Servidor%'

--Consultas a la tabla stock de ofisis
SELECT TOP 22000 STRMVK_SECTOR, STRMVK_DEPOSI, STRMVK_TIPAMJ, * FROM [dbo].[USR_STRMVK]
--WHERE STRMVK_DEPOSI like '%-acon'
--WHERE STRMVK_TIPAMJ = ''
ORDER BY STRMVK_FECALT desc
--INSERT INTO [SI_SECTOR]
SELECT DISTINCT STRMVK_TIPAMJ FROM [USR_STRMVK] as i
	LEFT JOIN [SI_SECTOR] as d ON d.NOMBRE_SECTOR = i.STRMVK_SECTOR
WHERE d.id is NULL

-- Consultas a tabla Productos ofisis
SELECT * FROM [dbo].[USR_STMPDH]
--WHERE STMPDH_CODFAL is not NULL
--WHERE STMPDH_ARTCOD = 'Y-R005KC5'
ORDER BY STMPDH_FECALT desc

-- Consultas a Productos
SELECT * FROM [dbo].[SI_PRODUCTO]
WHERE CODIGO_PRODUCTO = '1001-ABR 5'

-- Consultas a grupo
SELECT * FROM [dbo].[USR_GRUNEG]
SELECT * FROM [dbo].[SI_GRUPO] 
--WHERE NOMBRE_GRUPO = 'LAMPARA'
ORDER BY NOMBRE_GRUPO

-- Consultas a linea
SELECT * FROM [dbo].[USR_LINNEG]
ORDER BY LINNEG_DESCRP
SELECT * FROM [dbo].[SI_LINEA] 
--WHERE NOMBRE_LINEA = 'LAMPARA'
ORDER BY NOMBRE_LINEA

-- Consultas a proveedor
SELECT * FROM [dbo].[USR_PVMPRH]
WHERE PVMPRH_NOMBRE = 'MINDMAZE SA'
ORDER BY PVMPRH_NOMBRE
SELECT * FROM [dbo].[SI_PROVEEDOR]
--WHERE NOMBRE_LINEA = 'LAMPARA'
ORDER BY NOMBRE_PROVEEDOR

--consultas a las familias de los productos
SELECT * FROM [dbo].[USR_FAMALT]
SELECT * FROM [dbo].[SI_FAMILIA]

--DELETE FROM [STOCK_INVENTARIO] WHERE id = 3091 GUIA_DIGEMID --5104  5750 1922 7026       5794 4047
--DBCC CHECKIDENT('STOCK_INVENTARIO', RESEED, 0)
--INSERT INTO SI_PRODUCTO (CODIGO_PRODUCTO, DESCRIPCION)
--DELETE FROM [SI_DESCRIPCION]
--DBCC CHECKIDENT('SI_DESCRIPCION', RESEED, 0)
--CREATE INDEX SI_CodProd ON [dbo].[SI_PRODUCTO] (CODIGO_PRODUCTO);    -- 208594 + 31 = 208596?

UPDATE [dbo].[SI_DESCRIPCION]
	SET DESCRIPCION_ID = NULL

--INSERT INTO SI_DESCRIPCION (CODIGO_PRODUCTO, CANTIDAD, DESCRIPCION_ID, LOTE, TIPOALMACEN_ID, DEPOSITO_ID, SECTOR_ID, TIPO_ALMACENAJE)
SELECT t.cod, t.stock, t.st_id, t.STRMVK_NSERIE, t.tp_id, t.d_id, t.s_id, t.STRMVK_TIPAMJ
	FROM (SELECT DISTINCT TOP 480000 TRIM(STRMVK_ARTCOD) as cod, p.id as p_id, SUM(STRMVK_CANTID) as stock, i.STRMVK_NSERIE, d.id as d_id, i.STRMVK_DEPOSI, s.id as s_id, i.STRMVK_SECTOR, i.STRMVK_DESSEC, tp.id as tp_id, i.STRMVK_TIPALM, st.id as st_id, i.STRMVK_TIPAMJ, dc.id FROM [USR_STRMVK] as i
		LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STRMVK_ARTCOD)
		LEFT JOIN SI_DEPOSITO as d ON d.CODIGO_DEPOSITO = i.STRMVK_DEPOSI
		LEFT JOIN SI_SECTOR as s ON s.NOMBRE_SECTOR = TRIM(i.STRMVK_SECTOR)
		LEFT JOIN SI_TIPOALMACEN as tp ON tp.NOMBRE_ALMACEN = IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM)
		LEFT JOIN STOCK_INVENTARIO as st ON st.PRODUCTO_ID = p.id
		LEFT JOIN SI_DESCRIPCION as dc ON dc.DESCRIPCION_ID = st.id and 
				dc.LOTE = i.STRMVK_NSERIE and
				dc.TIPOALMACEN_ID = tp.id and
				dc.DEPOSITO_ID = d.id and
				dc.SECTOR_ID = s.id and
				dc.TIPO_ALMACENAJE = i.STRMVK_TIPAMJ
	WHERE dc.id is NULL
	GROUP BY TRIM(STRMVK_ARTCOD), p.id, STRMVK_NSERIE, d.id, STRMVK_DEPOSI, s.id, STRMVK_SECTOR, tp.id, STRMVK_TIPALM, st.id, i.STRMVK_TIPAMJ, i.STRMVK_DESSEC, dc.id
	ORDER BY TRIM(STRMVK_ARTCOD) desc) as t


-- Insert a Stock de Inventario
--INSERT INTO STOCK_INVENTARIO (PRODUCTO_ID, ALMACENAJE, STOCK)
SELECT st.p_id, st.tipo_almcenaje, st.stock FROM (
	SELECT TOP 60000 p.id as p_id, STRMVK_ARTCOD as cod, p.TIPO as tipo,  
		(e.EMPRESA + ' | ' + IIF(i.STRMVK_TIPAMJ = '', i.STRMVK_DEPOSI + ' - ' + i.STRMVK_SECTOR, i.STRMVK_TIPAMJ) + ' | ' + i.STRMVK_TIPALM) As tipo_almcenaje, SUM(STRMVK_CANTID) as stock 
	FROM [USR_STRMVK] as i
		LEFT JOIN [SI_PRODUCTO] as p ON p.CODIGO_PRODUCTO = i.STRMVK_ARTCOD and TIPO = i.STRMVK_TIPPRO
		LEFT JOIN [dbo].[SI_Empresa] As e ON e.id = i.STRMVK_CODEMP
	GROUP BY p.id, STRMVK_ARTCOD, p.TIPO, (e.EMPRESA + ' | ' + IIF(i.STRMVK_TIPAMJ = '', i.STRMVK_DEPOSI + ' - ' + i.STRMVK_SECTOR, i.STRMVK_TIPAMJ) + ' | ' + i.STRMVK_TIPALM) 
	ORDER BY STRMVK_ARTCOD, p_id desc
) as st

SELECT * FROM [USR_STRMVK]
WHERE STRMVK_ARTCOD =  ' 51202205' and STRMVK_TIPPRO = 'MER   '









-- Para UPDATE
SELECT 'DELETE' as Accion, * FROM deleted FOR XML PATH('movimiento'), ROOT('cambios')
SELECT 'INSERT' as Accion, * FROM inserted FOR XML PATH('movimiento'), ROOT('cambios')
-- Supongamos que cargas el XML en #MovimientosProcesar
-- Si el registro viene de una eliminación o la parte "old" de un update, multiplicas cant * -1
SELECT 
    p.id as p_id, 
    (e.EMPRESA + ' | ' + i.STRMVK_TIPAMJ + ' | ' + i.STRMVK_TIPALM) as alm,
    SUM(CASE WHEN i.Origen = 'DELETED' THEN i.STRMVK_CANTID * -1 ELSE i.STRMVK_CANTID END) as cant_neta
FROM #MovimientosProcesar i
... (joins)
GROUP BY p.id, e.EMPRESA, i.STRMVK_TIPAMJ, i.STRMVK_TIPALM
MERGE STOCK_INVENTARIO AS target
USING (...) AS source ON (...)
WHEN MATCHED THEN
    UPDATE SET 
        target.STOCK = target.STOCK + source.cant_neta, -- Suma el neto (si cant_neta es negativa, resta solo)
        target.USUARIO = 'Sync - ' + CAST(GETDATE() As VARCHAR(20))
WHEN NOT MATCHED THEN
    INSERT (PRODUCTO_ID, OTROS, STOCK, USUARIO)
    VALUES (source.p_id, source.alm, source.cant_neta, 'Sync Initial');

CREATE TRIGGER TR_ActualizarStockResumen
ON [USR_STRMVK]
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Manejar los nuevos registros (Suma al stock)
    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        MERGE STOCK_INVENTARIO AS target
        USING (
            SELECT 
                p.id as p_id, i.STRMVK_ARTCOD as cod, p.TIPO as tipo,
                (e.EMPRESA + ' | ' + i.STRMVK_TIPAMJ + ' | ' + i.STRMVK_TIPALM) as alm,
                SUM(i.STRMVK_CANTID) as cant
            FROM inserted i
            LEFT JOIN [SI_PRODUCTO] p ON p.CODIGO_PRODUCTO = i.STRMVK_ARTCOD AND p.TIPO = i.STRMVK_TIPPRO
            LEFT JOIN [dbo].[SI_Empresa] e ON e.id = i.STRMVK_CODEMP
            GROUP BY p.id, i.STRMVK_ARTCOD, p.TIPO, e.EMPRESA, i.STRMVK_TIPAMJ, i.STRMVK_TIPALM
        ) AS source
        ON (target.PRODUCTO_ID = source.p_id and target.OTROS = source.alm)
        WHEN MATCHED THEN
            UPDATE SET target.stock = target.stock + source.cant, target.PRODUCTO_ID = source.p_id
        WHEN NOT MATCHED THEN
            INSERT (PRODUCTO_ID, OTROS, stock)
            VALUES (source.p_id, source.alm, source.cant);
    END

    -- 2. Limpieza de ceros: Opcionalmente puedes borrar registros que lleguen a 0
    -- o manejarlos con la lógica de 'STOCK CERO' en una vista sobre esta tabla.
END
