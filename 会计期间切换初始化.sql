
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2020-2-1';
DECLARE @LocalCurrency nvarchar(50);
select @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';


-- APDate初始化
DECLARE @APDate date;
SELECT @APDate=APDate FROM Cogs_APDate where APDate=@CurrentAPDate;

INSERT INTO Cogs_APDate (APDate, Closed)
SELECT top 1 @CurrentAPDate, 0
FROM Cogs_APDate 
WHERE APDate<@CurrentAPDate AND @APDate is null
ORDER BY APDate DESC
;

-- TaxRate初始化
DECLARE @TaxRate decimal(18,6);
SELECT @TaxRate=Rate FROM Cogs_TaxRate where APDate=@CurrentAPDate;

INSERT INTO Cogs_TaxRate (APDate, TaxCode, Name, Rate)
SELECT top 1 @CurrentAPDate, 'TAX', 'VAT', Rate
FROM Cogs_TaxRate 
WHERE APDate<@CurrentAPDate AND @TaxRate is null
ORDER BY APDate DESC
;

-- ExchangeRate初始化
DECLARE @ExchangeRateCnt integer;
select @ExchangeRateCnt = count(*) From Cogs_ExchangeRate Where [ToCurrency]=@LocalCurrency AND [FromCurrency]='USD' AND APDate=@CurrentAPDate;

INSERT INTO Cogs_ExchangeRate (APDate, FromCurrency, ToCurrency, Rate)
SELECT top 1 @CurrentAPDate, FromCurrency, ToCurrency, Rate
FROM Cogs_ExchangeRate 
WHERE APDate<@CurrentAPDate AND [ToCurrency]=@LocalCurrency AND [FromCurrency]='USD' AND @ExchangeRateCnt=0
ORDER BY APDate DESC
;

-- Markup初始化
DECLARE @MarkupRate decimal(18,6);
SELECT @MarkupRate=Rate FROM Cogs_MarkupRate where APDate=@CurrentAPDate;

INSERT INTO Cogs_MarkupRate (APDate, Rate)
SELECT top 1 @CurrentAPDate, Rate
FROM Cogs_MarkupRate 
WHERE APDate<@CurrentAPDate AND @MarkupRate is null
ORDER BY APDate DESC
;

-- 减值MST初始化
DECLARE @ItemImpairCnt integer;
SELECT @ItemImpairCnt=count(*) FROM Cogs_ItemImpair where APDate=@CurrentAPDate;

DECLARE @ItemImpairCopyAPDate date;
SELECT @ItemImpairCopyAPDate=max(APDate) FROM Cogs_ItemImpair where APDate<@CurrentAPDate AND @ItemImpairCnt=0;

Delete From Cogs_ItemImpair where APDate=@CurrentAPDate;
INSERT INTO Cogs_ItemImpair (APDate, Brand, StoreType, FNSeason, SeasonYear, ImpairType, ImpairYear)
SELECT @CurrentAPDate, Brand, StoreType, FNSeason, SeasonYear, ImpairType, ImpairYear
FROM Cogs_ItemImpair 
WHERE APDate = @ItemImpairCopyAPDate
;
