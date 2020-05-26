/*
go
ALTER DATABASE Text_Analytics SET COMPATIBILITY_LEVEL = 110
go
use Text_Analytics

IF OBJECT_ID('BUYS_SEP','U') IS NOT NULL
DROP TABLE BUYS_SEP;
IF OBJECT_ID('CLICKS_SEP','U') IS NOT NULL
DROP TABLE CLICKS_SEP;

SELECT *
INTO BUYS_SEP
FROM [dbo].[buys] 
WHERE CONVERT(date,Time_Stamp) BETWEEN '2014-09-01 ' AND '2014-09-30'
AND Quantity>0

SELECT *
INTO CLICKS_SEP
FROM [dbo].[clicks] C
WHERE CONVERT(date, C.Time_Stamp) BETWEEN '2014-08-31' AND '2014-09-30';

SELECT C. Category,
AVG(CAST(B.Price AS numeric(12,0))) AS AVG_Pric
INTO AVG_PRIC_CTG
FROM [dbo].[CLICKS_SEP] C LEFT JOIN [dbo].[buys] B ON C.ItemID=B.ItemID
GROUP BY C.Category

	/*
	SELECT DISTINCT 
	Category,
	PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY Price) OVER (PARTITION BY Category) AS Pri_ctg_P90
	INTO Pric_P90_ctg
	FROM [dbo].[TEMP_Pric_P90_ctg]
	*/


*/

SELECT DISTINCT 
B.SessionID AS Buy_sesID,
C.ItemID AS Cli_ItemID,
A.ttl_Cli,
A.AVG_CLI,
I.Item_CLI,
CASE WHEN I.Item_CLI>A.AVG_CLI THEN 1
	ELSE 0 END AS Fre_Cli_Itm,
CASE WHEN CG.RN = 1 THEN 1
	ELSE 0 END AS IN_Fre_Ctg,
DT.Cli_Wd,
CASE WHEN DT.Cli_H >= 0 AND DT.Cli_H < 6 THEN 1
	 WHEN DT.Cli_H >= 6 AND DT.Cli_H < 12 THEN 2
	 WHEN DT.Cli_H >= 12 AND DT.Cli_H < 18 THEN 3
	 ELSE 4 END AS Cli_T,
DS.Dur_Sec,
CASE WHEN DS.dur_sec =0 THEN 1
	WHEN DS.dur_sec>0 and DS.dur_sec<10 THEN 2
	ELSE 3 END AS Cli_buy,
CASE WHEN IB.CNT >=111 THEN 1
	ELSE 0 END AS Item_bought_P90,
CASE WHEN  C.ItemID = FLI.ItemID THEN 1
	ELSE 0 END AS Fir_Cli,
CASE WHEN C.ItemID = FLI.ItemID THEN 1
	ELSE 0 END AS Las_Cli,
HP.Item_avg_pric,
APC.AVG_Pric,
PPC.Pri_ctg_P90,
CASE WHEN PT.Pred_Target =1 THEN 1
	ELSE 0 END AS Pred_Target

FROM  BUYS_SEP B
LEFT JOIN CLICKS_SEP C ON B.SessionID = C.SessionID
LEFT JOIN [dbo].[AVG_PRIC_CTG] APC ON C.Category = APC.Category 
LEFT JOIN [dbo].[Pric_P90_ctg] ppc ON C.Category = PPC.Category
LEFT JOIN 
			-- TTL & AVG Click Times in each Click Session
			(SELECT C.SessionID,
			COUNT(C.Time_Stamp) AS ttl_Cli,
			CAST(COUNT(C.Time_Stamp)/CAST(COUNT(DISTINCT C.ItemID)AS FLOAT) AS DECIMAL(38,2)) AS AVG_CLI
			FROM CLICKS_SEP C
			GROUP BY SessionID) A ON C.SessionID=A.SessionID
LEFT JOIN 
			-- TTL Click times on each Item in each Click Session
			(SELECT SessionID,
			ItemID,
			COUNT(Time_Stamp) AS Item_CLI
			FROM CLICKS_SEP 
			GROUP BY SessionID, ItemID) I ON  C.SessionID= I.SessionID AND C.ItemID=I.ItemID
LEFT JOIN
			-- Top 1 Clicked Category in each Click Session
			(SELECT 
			SessionID,
			Category,
			ROW_NUMBER() OVER(PARTITION BY SessionID ORDER BY COUNT(CATEGORY) DESC) AS RN
			FROM CLICKS_SEP
			GROUP BY SessionID,Category
			) CG ON C.SessionID = CG.SessionID AND C.Category = CG.Category
LEFT JOIN
			-- Bought item in each buy session as the Predictive Target
			(SELECT DISTINCT
			SessionID,
			ItemID,
			1 AS Pred_Target
			FROM BUYS_SEP) PT ON C.SessionID=PT.SessionID AND C.ItemID=PT.ItemID

LEFT JOIN 
			-- Click Weekday and Hour
			(SELECT SessionID,
			ItemID,
			Time_Stamp,
			DATENAME(DW, CONVERT(datetime, Time_Stamp)) AS Cli_Wd,
			DATEPART(HOUR, CONVERT(datetime, Time_Stamp)) AS Cli_H
			FROM CLICKS_SEP) DT
			ON C.SessionID=DT.SessionID AND C.ItemID=DT.ItemID

LEFT JOIN 
			-- Click duration for each Item in each Click session
			(SELECT 
			SessionID,
			ItemID,
			datediff(second, MIN(CONVERT(datetime, Time_Stamp)),MAX(CONVERT(datetime, Time_Stamp))) dur_sec
			FROM CLICKS_SEP
			GROUP BY SessionID, ItemID) DS ON C.SessionID =DS.SessionID AND C.ItemID=DS.ItemID

LEFT JOIN 
			-- Item bought times in history
			(SELECT ItemID, 
			COUNT (ItemID) AS CNT
			FROM [dbo].[buys]
			GROUP BY ItemID) IB ON C.ItemID = IB. ItemID

LEFT JOIN
			-- First and Last Clicked Item in each Click session
			(SELECT SessionID, ItemID
			FROM 
			(SELECT DISTINCT 
			SessionID,
			ItemID,
			RnAsc = ROW_NUMBER() OVER(PARTITION BY SessionID ORDER BY Time_Stamp),
			RnDesc = ROW_NUMBER() OVER(PARTITION BY SessionID ORDER BY Time_Stamp DESC) 
			FROM [dbo].[clicks]
			) CO
			WHERE CO.RnAsc = 1 OR CO.RnDesc = 1) FLI ON C.SessionID = FLI.SessionID AND C.ItemID = FLI.ItemID
LEFT JOIN 
			--Item average Price in history
			(SELECT DISTINCT
			ItemID,
			AVG(Price) AS Item_avg_pric 
			From [dbo].[buys]
			GROUP BY ItemID) HP ON C.ItemID=HP.ItemID


--WHERE CONVERT(date, B.Time_Stamp) BETWEEN '2014-09-24' AND '2014-09-30'

ORDER BY B.SessionID


 