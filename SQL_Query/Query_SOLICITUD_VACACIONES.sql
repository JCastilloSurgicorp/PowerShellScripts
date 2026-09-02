SELECT * FROM [dbo].[SV_UPDATE_AUDIT]
SELECT * FROM [dbo].[EU_Puestos]
SELECT * FROM [dbo].[auth_group]
SELECT * FROM [dbo].[auth_permission]
SELECT * FROM [dbo].[auth_group_permissions]
SELECT * FROM [dbo].[extended_users_groups]
SELECT * FROM [dbo].[extended_users_user_permissions]
SELECT * FROM [dbo].[EU_Area]

--ALTER LOGIN j4ir0st WITH DEFAULT_DATABASE = [SURGICORP_ERP];  4

--DROP TABLE [dbo].[auth_user]

SELECT id, OBSERVACIONES, * FROM [dbo].[SOLICITUD_VACACIONES]
--WHERE USUARIO_ID = 62
WHERE MOTIVO like 'Solicitud para restar días utilizados anteriormente.%'

SELECT * FROM [dbo].[extended_users]
WHERE id = 5

--DELETE FROM [SOLICITUD_VACACIONES] WHERE id > 463229 GUIA_DIGEMID 16 30 80 90
--DBCC CHECKIDENT('SOLICITUD_VACACIONES', RESEED, 0)

UPDATE [SOLICITUD_VACACIONES]
	SET OBSERVACIONES = ''
	WHERE id = 67 --80 - 92		101 - 209	211 - 232	
