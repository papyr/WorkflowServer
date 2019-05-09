/*
Company: OptimaJet
Project: WorkflowServer MSSQL
Version: 2
File: WorkflowServerScripts.sql
*/

IF NOT EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = N'WorkflowServerStats')
BEGIN

	CREATE TABLE [dbo].[WorkflowServerStats](
		[Id] [uniqueidentifier] NOT NULL,
		[Type] [nvarchar](256) NOT NULL,
		[DateFrom] [datetime] NOT NULL,
		[DateTo] [datetime] NOT NULL,
		[Duration] [int] NOT NULL,
		[IsSuccess] [bit] NOT NULL,
		[ProcessId] [uniqueidentifier] NULL,
	 CONSTRAINT [PK_WorkflowServerStats] PRIMARY KEY NONCLUSTERED 
	(
		[Id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[WorkflowServerStats] ADD  CONSTRAINT [DF_WorkflowServerStats_IsSuccess]  DEFAULT ((1)) FOR [IsSuccess]

END

IF NOT EXISTS (SELECT 1 FROM [INFORMATION_SCHEMA].[TABLES] WHERE [TABLE_NAME] = N'WorkflowServerProcessHistory')
BEGIN

	CREATE TABLE [dbo].[WorkflowServerProcessHistory] (
		  Id UNIQUEIDENTIFIER NOT NULL
		 ,ProcessId UNIQUEIDENTIFIER NOT NULL
		 ,IdentityId NVARCHAR(256) NULL
		 ,AllowedToEmployeeNames NVARCHAR(MAX) NOT NULL
		 ,TransitionTime DATETIME NULL
		 ,[Order] BIGINT IDENTITY
		 ,InitialState NVARCHAR(1024) NOT NULL
		 ,DestinationState NVARCHAR(1024) NOT NULL
		 ,Command NVARCHAR(1024) NOT NULL
		 ,CONSTRAINT PK_WorkflowServerProcessHistory PRIMARY KEY NONCLUSTERED (Id)
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

	CREATE CLUSTERED INDEX IX_WorkflowServerProcessHistory
	ON [dbo].[WorkflowServerProcessHistory] (ProcessId, [Order])
	ON [PRIMARY]
	
	ALTER TABLE [dbo].[WorkflowServerProcessHistory]
	ADD CONSTRAINT FK_WorkflowServerProcessHistory_WorkflowServerProcessHistory FOREIGN KEY (Id) REFERENCES dbo.WorkflowServerProcessHistory (Id)
END


ALTER TABLE [dbo].[WorkflowInbox] ALTER COLUMN [IdentityId] NVARCHAR(256) NOT NULL


IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'WorkflowReportBySchemes')
BEGIN
	EXECUTE('CREATE PROCEDURE [WorkflowReportBySchemes] 
	AS
	BEGIN
		SELECT
			ws.Code,
			(SELECT COUNT(inst.Id) FROM WorkflowProcessInstance inst
				LEFT JOIN WorkflowProcessScheme ps on ps.Id = inst.SchemeId
				WHERE ISNULL(ps.RootSchemeCode, ps.SchemeCode) = ws.Code) as [ProcessCount],
			(SELECT COUNT(history.Id) FROM WorkflowProcessTransitionHistory history
			LEFT JOIN WorkflowProcessInstance inst on history.ProcessId = inst.Id
			LEFT JOIN WorkflowProcessScheme ps on ps.Id = inst.SchemeId
			WHERE ISNULL(ps.RootSchemeCode, ps.SchemeCode) = ws.Code) as [TransitionCount]
		FROM WorkflowScheme ws
	
	END')
	PRINT 'WorkflowReportBySchemes CREATE PROCEDURE'
END


IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'WorkflowReportByTransitions')
BEGIN
	EXECUTE('CREATE PROCEDURE WorkflowReportByTransitions
	@from datetime,
	@to datetime,
	@period int -- 0 - MONTH, 1 - DAY, 2 - HOUR, 3 - MINUTE, 4 - SECOND 
	AS
	BEGIN
		DECLARE @periods table (
			df datetime NOT NULL,
			de datetime NOT NULL
		);

		IF @from > @to 
			RETURN;

		DECLARE @date datetime, @dateend datetime
		SET @date = DATEADD(MONTH, MONTH(@from)-1, DATEADD(YEAR, YEAR(@from) - 1900, 0));
		IF @period >= 1
			SET @date = DATEADD(DAY, DAY(@from) - 1, @date);
		IF @period >= 2
			SET @date = DATEADD(HOUR, DATEPART(HOUR, @from), @date);
		IF @period >= 3
			SET @date = DATEADD(MINUTE, DATEPART(MINUTE, @from), @date);
		IF @period >= 4
			SET @date = DATEADD(SECOND, DATEPART(SECOND, @from), @date);
		
		WHILE @date <= @to 
		BEGIN
			SET @dateend = CASE 
				WHEN @period = 0 THEN DateAdd(MONTH, 1, @date) 
				WHEN @period = 1 THEN DateAdd(DAY, 1, @date) 
				WHEN @period = 2 THEN DateAdd(HOUR, 1, @date) 
				WHEN @period = 3 THEN DateAdd(MINUTE, 1, @date) 
				WHEN @period = 4 THEN DateAdd(SECOND, 1, @date) 
				END;
			INSERT INTO @periods (df, de) SELECT @date, @dateend
			SET @date = @dateend
		END

		SELECT 
			p.df as [Date],
			scheme.Code as SchemeCode,
			ISNULL(COUNT(history.Id), 0) as [Count]
		FROM @periods p
		LEFT JOIN WorkflowScheme scheme on 1=1
		LEFT JOIN WorkflowProcessScheme ps on scheme.Code = ISNULL(ps.RootSchemeCode, ps.SchemeCode)
		LEFT JOIN WorkflowProcessInstance inst on ps.Id = inst.SchemeId
		LEFT JOIN WorkflowProcessTransitionHistory history on history.ProcessId = inst.Id AND history.TransitionTime >= p.df AND history.TransitionTime < p.de
		GROUP BY p.df, scheme.Code
		ORDER BY p.df, scheme.Code
	END')
	PRINT 'WorkflowReportByTransitions CREATE PROCEDURE'
END


IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'WorkflowReportByStats')
BEGIN
	EXECUTE('CREATE PROCEDURE [dbo].[WorkflowReportByStats] 	
	@from datetime,
	@to datetime,
	@period int -- 0 - MONTH, 1 - DAY, 2 - HOUR, 3 - MINUTE, 4 - SECOND 
	AS
	BEGIN

		DECLARE @periods table (
			df datetime NOT NULL,
			de datetime NOT NULL
		);

		IF @from > @to 
			RETURN;

		DECLARE @date datetime, @dateend datetime
		SET @date = DATEADD(MONTH, MONTH(@from)-1, DATEADD(YEAR, YEAR(@from) - 1900, 0));
		IF @period >= 1
			SET @date = DATEADD(DAY, DAY(@from) - 1, @date);
		IF @period >= 2
			SET @date = DATEADD(HOUR, DATEPART(HOUR, @from), @date);
		IF @period >= 3
			SET @date = DATEADD(MINUTE, DATEPART(MINUTE, @from), @date);
		IF @period >= 4
			SET @date = DATEADD(SECOND, DATEPART(SECOND, @from), @date);
		
		WHILE @date <= @to 
		BEGIN
			SET @dateend = CASE 
				WHEN @period = 0 THEN DateAdd(MONTH, 1, @date) 
				WHEN @period = 1 THEN DateAdd(DAY, 1, @date) 
				WHEN @period = 2 THEN DateAdd(HOUR, 1, @date) 
				WHEN @period = 3 THEN DateAdd(MINUTE, 1, @date) 
				WHEN @period = 4 THEN DateAdd(SECOND, 1, @date) 
				END;
			INSERT INTO @periods (df, de) SELECT @date, @dateend
			SET @date = @dateend
		END

		DECLARE @schemes table (
			Code nvarchar(256) NULL
		);

		INSERT @schemes (Code) 
		SELECT DISTINCT ISNULL(ps.RootSchemeCode, ps.SchemeCode) FROM WorkflowServerStats stats
		LEFT JOIN WorkflowProcessInstance inst on inst.Id = stats.ProcessId
		LEFT JOIN WorkflowProcessScheme ps on inst.SchemeId = ps.Id
		WHERE DateFrom >= @from AND DateFrom < @to

		DECLARE @types table (
			Code nvarchar(256) NOT NULL
		);

		INSERT @types (Code) 
		SELECT DISTINCT [Type] FROM WorkflowServerStats stats
		WHERE stats.DateFrom >= @from AND stats.DateFrom < @to

		DECLARE @success table (
			Value bit NOT NULL
		);

		INSERT @success (Value) VALUES(0)
		INSERT @success (Value) VALUES(1)

		SELECT 
			p.df as [Date],
			scheme.Code as SchemeCode,
			types.Code as [Type],
			success.Value as [IsSuccess],
			ISNULL(COUNT(stats.Id), 0) as [Count],
			ISNULL(AVG(stats.Duration), 0) as [DurationAVG],
			ISNULL(MIN(stats.Duration), 0) as [DurationMIN],
			ISNULL(MAX(stats.Duration), 0) as [DurationMAX]
		FROM @periods p
		LEFT JOIN @schemes scheme on 1=1
		LEFT JOIN @types types on 1=1
		LEFT JOIN @success success on 1=1
		LEFT JOIN WorkflowServerStats stats on stats.[Type] = types.Code AND stats.IsSuccess = success.Value AND stats.DateFrom >= p.df AND stats.DateFrom < p.de
		LEFT JOIN WorkflowProcessInstance inst on stats.ProcessId = inst.Id
		LEFT JOIN WorkflowProcessScheme ps on ps.Id = inst.SchemeId AND scheme.Code = ps.SchemeCode
		GROUP BY p.df, scheme.Code, types.Code, success.Value
		ORDER BY p.df, scheme.Code, types.Code, success.Value
	END')
	PRINT 'WorkflowReportByStats CREATE PROCEDURE'
END


IF NOT EXISTS (
  SELECT * 
  FROM   sys.columns 
  WHERE  object_id = OBJECT_ID(N'[dbo].[WorkflowScheme]')
         AND name = 'DeleteFinalized'
)
BEGIN
 ALTER TABLE [dbo].[WorkflowScheme] ADD [DeleteFinalized] BIT NOT NULL DEFAULT (0)
END


IF NOT EXISTS (
  SELECT *
  FROM   sys.columns
  WHERE  object_id = OBJECT_ID(N'[dbo].[WorkflowScheme]')
         AND name = 'DontFillIndox'
)
BEGIN
 ALTER TABLE [dbo].[WorkflowScheme] ADD [DontFillIndox] BIT NOT NULL DEFAULT (0)
END


IF NOT EXISTS (
  SELECT *
  FROM   sys.columns
  WHERE  object_id = OBJECT_ID(N'[dbo].[WorkflowScheme]')
         AND name = 'DontPreExecute'
)
BEGIN
 ALTER TABLE [dbo].[WorkflowScheme] ADD [DontPreExecute] BIT NOT NULL DEFAULT (0)
END

