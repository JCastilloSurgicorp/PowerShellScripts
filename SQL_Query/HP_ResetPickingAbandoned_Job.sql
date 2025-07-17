USE msdb;
GO

-- Crear el trabajo
EXEC dbo.sp_add_job
    @job_name = N'HP_ResetPickingAbandoned_Job',
    @enabled = 1,
    @description = N'Resetea sesiones de picking abandonadas cada 2 minutos';
GO

-- Agregar paso al trabajo
EXEC sp_add_jobstep
    @job_name = N'HP_ResetPickingAbandoned_Job',
    @step_name = N'Ejecutar HP_AbandonedSession_SP',
    @subsystem = N'TSQL',
    @command = N'EXEC HP_AbandonedSession_SP;',
    @database_name = N'SURGICORP_ERP'; 
GO

-- Crear programación (cada 2 minutos)
EXEC sp_add_schedule
    @schedule_name = N'HP_Cada_2_Minutos',
    @freq_type = 4,              -- Diariamente
    @freq_interval = 1,          -- Todos los días
    @freq_subday_type = 4,       -- Unidad de tiempo: Minutos
    @freq_subday_interval = 2,   -- Cada 2 minutos
    @active_start_time = 000000, -- Inicio: 00:00:00
    @active_end_time = 235959;   -- Fin: 23:59:59
GO

-- Asignar programación al trabajo
EXEC sp_attach_schedule
    @job_name = N'HP_ResetPickingAbandoned_Job',
    @schedule_name = N'HP_Cada_2_Minutos';
GO

-- Asignar trabajo al servidor local
EXEC sp_add_jobserver
    @job_name = N'HP_ResetPickingAbandoned_Job',
    @server_name = N'(local)';
GO

EXEC msdb.dbo.sp_start_job N'HP_ResetPickingAbandoned_Job';