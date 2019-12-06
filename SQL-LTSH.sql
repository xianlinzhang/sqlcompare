


################################################   -1. 入库数据清空     ################################################
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';
-- 清空Cogs_PurchaseSale入库成本数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate and Change='Increase';
-- 清楚入库成本分配标识
update Cogs_StockIn set AllocatedFlg = null FROM Cogs_StockIn WHERE APDate=@CurrentAPDate;
update Cogs_StockInAdjustment set AllocatedFlg = null FROM Cogs_StockInAdjustment WHERE APDate=@CurrentAPDate
update Cogs_LotPOInvoiceRef set AllocatedFlg = null FROM Cogs_LotPOInvoiceRef WHERE APDate=@CurrentAPDate
;
-- StockIn APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockIn as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 入库调整单 APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockInAdjustment as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 清空 APDate PurchaseCostAllocated
update Cogs_APDate
set
PurchaseCostAllocated=0
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;


################################################   -2. 结转数据清空     ################################################
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';
-- 清空Cogs_PurchaseSale结转成本数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate AND Change='Decrease';
-- 清楚入库成本分配标识
update Cogs_Sales set AllocatedFlg = null FROM Cogs_Sales WHERE APDate=@CurrentAPDate;
update Cogs_StockMovement set AllocatedFlg = null FROM Cogs_StockMovement WHERE APDate=@CurrentAPDate;
update Cogs_StockMovementSpecial set AllocatedFlg = null FROM Cogs_StockMovementSpecial WHERE APDate=@CurrentAPDate;
update Cogs_InventoryAdjustment set AllocatedFlg = null FROM Cogs_InventoryAdjustment WHERE APDate=@CurrentAPDate;
-- 销售 APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[SalesDate] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_Sales as sm
WHERE sm.[SalesDate]>=@CurrentAPDate And sm.[SalesDate]<DATEADD(month,1,@CurrentAPDate)
;
-- 库存移动单 APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockMovement as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 库存移动单 APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockMovementSpecial as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 库存调整单 APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_InventoryAdjustment as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;

-- 清空 APDate WriteoffCostAllocated
update Cogs_APDate
set
WriteoffCostAllocated=0
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;


################################################   -3. 单位成本清空     ################################################
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';

-- 清空 APDate UnitCostingCalculated
update Cogs_APDate
set
UnitCostingCalculated=0
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;


################################################   0. 会计期间数据初始化     ################################################
-- change tao 12/2
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';
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





################################################   1. 入库成本分配（入库单+入库调整单）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @OtherCostAMT decimal(18,6);
DECLARE @LocalCurrency nvarchar(50);
DECLARE @MonthStockinQty integer;
DECLARE @MonthStockinAmt integer;

set @CurrentAPDate = '2019-11-1';
select @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';


-- 设置APDate对应PurchaseCostAllocated
update Cogs_APDate
set
PurchaseCostAllocated=1
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;

-- 删除不是本地仓库的入库单
delete Cogs_StockIn from Cogs_StockIn as si
LEFT JOIN Cogs_Warehouse as w ON w.Code=si.Location
Where w.Code is null AND si.APDate=@CurrentAPDate
;

-- 删除 ZOO/CNBAG01-CNBAG05/R00/R08/ALT/PKG的商品的入库
delete Cogs_StockIn from Cogs_StockIn as si
Where si.APDate=@CurrentAPDate
AND ( si.ItemCode like '%ZOO%' OR si.ItemCode like '%CNBAG%' OR si.ItemCode like '%R00%' OR si.ItemCode like '%R08%' OR si.ItemCode like '%ALT%' OR si.ItemCode like '%PKG%' )
;

-- 计算Stockin Currency
update si
SET si.Currency = v.Currency
FROM Cogs_StockIn as si
LEFT JOIN Cogs_Item as i ON i.ItemCode=si.ItemCode
LEFT JOIN Cogs_Vendor as v ON v.VendorAccountNumber=i.VendorAccountNumber
WHERE si.ApDate=@CurrentAPDate
;

-- 更新关税表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_TariffInvoice as tr
LEFT JOIN Cogs_LotTariffRef as ltr ON ltr.TaxBillNo = tr.TaxBillNo
WHERE ltr.APDate=@CurrentAPDate;
-- 更新运费表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_FreightInvoice as tr
LEFT JOIN Cogs_LotFreightRef as ltr ON ltr.FreightNo = tr.FreightNo AND ltr.CustomsNo = tr.CustomsNo
WHERE ltr.APDate=@CurrentAPDate;
-- 更新ASNInvoice的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_POInvoice  as tr
LEFT JOIN Cogs_LotPOInvoiceRef as ltr ON ltr.ASNInvoiceNo = tr.ASNInvoiceNo
WHERE ltr.APDate=@CurrentAPDate
;
-- 更新入库表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_StockIn  as tr
LEFT JOIN Cogs_LotPOInvoiceRef as ltr ON ltr.ASNInvoiceNo = tr.ASNInvoiceNo
WHERE tr.APDate=@CurrentAPDate
;

-- 生成本次新增批次信息
-- DELETE FROM Cogs_Lot where APDate = @CurrentAPDate;
INSERT INTO Cogs_Lot (CreateTime, UpdateTime, APDate, LotNo, TtlQty, TtlAmt, TtlTariffAmt, TtlFreightAmt)
SELECT lir.CreateTime, lir.UpdateTime, @CurrentAPDate, lir.LotNo, lir.TtlQty, lir.TtlAmt, tr1.TtlTariffAmt, fr.TtlFreightAmt
FROM (SELECT getDate() as CreateTime, getDate() as UpdateTime, LotNo, sum(Qty) as TtlQty, sum(Qty*UnitPrice) as TtlAmt FROM Cogs_POInvoice WHERE LotNo is not null GROUP BY LotNo) as lir
LEFT JOIN (SELECT LotNo, sum(PayAmount) as TtlTariffAmt FROM Cogs_TariffInvoice WHERE TaxType='01' GROUP BY LotNo) as tr1 ON tr1.LotNo=lir.LotNo
LEFT JOIN (SELECT LotNo, sum(Amount) as TtlFreightAmt FROM Cogs_FreightInvoice GROUP BY LotNo) as fr ON fr.LotNo=lir.LotNo
LEFT JOIN Cogs_Lot as cl ON cl.LotNo=lir.LotNo
WHERE cl.LotNo is null
;
-- 新增批次关联Stockin信息
DELETE FROM Cogs_LotStockIn where APDate = @CurrentAPDate;
INSERT into Cogs_LotStockIn (CreateTime, UpdateTime, APDate, LotNo, TtlQty, TtlAmt, TtlTariffAmt, TtlFreightAmt)
SELECT getDate() as CreateTime, getDate() as UpdateTime, @CurrentAPDate, lir.LotNo, lir.TtlQty, lir.TtlAmt, cl.TtlTariffAmt/cl.TtlAmt*lir.TtlAmt, cl.TtlFreightAmt/cl.TtlQty*lir.TtlQty
FROM (SELECT max(CreateTime) as CreateTime,max(UpdateTime) as UpdateTime, LotNo, sum(Qty) as TtlQty, sum(Qty*UnitPrice) as TtlAmt FROM Cogs_StockIn WHERE APDate=@CurrentAPDate AND LotNo is not Null GROUP BY LotNo) as lir
LEFT JOIN Cogs_Lot as cl ON cl.LotNo=lir.LotNo
WHERE cl.LotNo is not null
;
-- 更新已入库数量和金额，已分摊关税和运费
UPDATE l
SET 
UpdateTime = getDate(),
TtlStockQty = isNull(frb.TtlQty,0),
TtlStockAmt = isNull(frb.TtlAmt,0),
TtlStockTariffAmt = isNull(frb.TtlTariffAmt,0),
TtlStockFreightAmt = isNull(frb.TtlFreightAmt,0),
AllocatedQty = isNull(frc.TtlQty,0),
AllocatedAmt = isNull(frc.TtlAmt,0),
AllocatedTariffAmt = 
case 
when l.AllocatedAllTariffFlg=@CurrentAPDate then l.TtlTariffAmt-isNull(frb.TtlTariffAmt,0)
else isNull(frc.TtlTariffAmt,0)
end,
AllocatedFreightAmt = 
case 
when l.AllocatedAllFreightFlg=@CurrentAPDate then l.TtlFreightAmt-isNull(frb.TtlFreightAmt,0)
else isNull(frc.TtlFreightAmt,0)
end
FROM Cogs_Lot as l
LEFT JOIN (SELECT LotNo, sum(TtlQty) as TtlQty, sum(TtlAmt) as TtlAmt, sum(TtlTariffAmt) as TtlTariffAmt, sum(TtlFreightAmt) as TtlFreightAmt FROM Cogs_LotStockIn WHERE APDate<@CurrentAPDate GROUP BY LotNo) as frb ON frb.LotNo=l.LotNo
LEFT JOIN (SELECT LotNo, sum(TtlQty) as TtlQty, sum(TtlAmt) as TtlAmt, sum(TtlTariffAmt) as TtlTariffAmt, sum(TtlFreightAmt) as TtlFreightAmt FROM Cogs_LotStockIn WHERE APDate=@CurrentAPDate GROUP BY LotNo) as frc ON frc.LotNo=l.LotNo
WHERE frc.LotNo is not null
;

UPDATE frc
SET 
TtlTariffAmt = 
case 
when l.AllocatedAllTariffFlg=@CurrentAPDate then isNull(l.AllocatedTariffAmt,0)
else frc.TtlTariffAmt
end,
TtlFreightAmt = 
case 
when l.AllocatedAllFreightFlg=@CurrentAPDate then isNull(l.AllocatedFreightAmt,0)
else frc.TtlFreightAmt
end
FROM Cogs_LotStockIn as frc
LEFT JOIN Cogs_Lot as l ON frc.LotNo=l.LotNo
WHERE frc.LotNo is not null AND frc.APDate=@CurrentAPDate
;





-- 生成当月其他费用汇总
select @OtherCostAMT = sum(Amount) From Cogs_OtherFeeInvoice Where APDate=@CurrentAPDate;
select @MonthStockinQty = sum(Qty) From Cogs_StockIn Where APDate=@CurrentAPDate;
select @MonthStockinAmt = sum(Qty*UnitPrice) From Cogs_StockIn Where APDate=@CurrentAPDate; --change tao 12/3

-- 清空进销存入库单
DELETE FROM Cogs_PurchaseSale where APDate=@CurrentAPDate and Type='Stockin';

-- change tao 12/3
-- 入库单 转进销存
INSERT INTO Cogs_PurchaseSale (
CreateTime,UpdateTime,APDate,Type,Change,[Date],StoreCode,
ItemColor,Qty,AmountDC,Currency, ExchangeRate,
LotNo, ASNInvoiceNo, TariffAMT, FreightAMT, OtherCostAMT)
SELECT 
getdate(), getDate(), @CurrentAPDate, 'Stockin', 'Increase', max(sm.[Date]), LEFT(sm.Location,4),
sm.ItemCode+sm.ColorCode, sum(sm.Qty), sum(sm.Qty*sm.UnitPrice), sm.Currency, max(er.Rate), 
sm.LotNo, sm.ASNInvoiceNo, max(lt.TtlTariffAmt)/max(lt.TtlAmt)*sum(sm.Qty*sm.UnitPrice), max(lt.TtlFreightAmt)/max(lt.TtlQty)*sum(sm.Qty), 
case 
when @LocalCurrency='HKD' then @OtherCostAMT/@MonthStockinAmt*sum(sm.Qty*sm.UnitPrice)
when @LocalCurrency='CNY' then @OtherCostAMT/@MonthStockinQty*sum(sm.Qty)
end
FROM Cogs_StockIn as sm
LEFT JOIN Cogs_ExchangeRate as er ON er.FromCurrency = sm.Currency and er.ToCurrency=@LocalCurrency AND er.APDate=@CurrentAPDate
LEFT JOIN Cogs_LotStockIn as lt ON lt.LotNo = sm.LotNo AND lt.APDate=@CurrentAPDate AND lt.LotNo is not null
LEFT JOIN Cogs_Warehouse as w ON w.Code = sm.Location
WHERE sm.APDate=@CurrentAPDate AND sm.Location is not Null AND w.Code is not null
GROUP BY sm.LotNo, sm.ASNInvoiceNo, sm.Currency, sm.Location, sm.ItemCode, sm.ColorCode
;




-- 进销存 入库数据 计算Amount金额 
-- 是否需要将费用成本一起加入并覆盖AmountLC ？？？？？
Update ps
set 
ps.ProductCostAmt = ( isNull(ps.AmountDC,0) * isNull(ps.ExchangeRate,0) ),
ps.InwardCostAmt = isNull(ps.TariffAMT,0) + isNull(ps.FreightAMT,0) + isNull(ps.OtherCostAMT,0),
ps.AmountLC = ( isNull(ps.AmountDC,0) * isNull(ps.ExchangeRate,0) ) + isNull(ps.TariffAMT,0) + isNull(ps.FreightAMT,0) + isNull(ps.OtherCostAMT,0)
FROM Cogs_PurchaseSale as ps
WHERE ps.APDate=@CurrentAPDate AND ps.change='Increase'
;



-- 设置分配FLG
update Cogs_StockIn
Set AllocatedFlg = 1
FROM Cogs_StockIn
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;








----------------------------------------------入库调整单


-- 清空入库调整单数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate and Type='StockinAdjustment';
-- 库存调整单加入进销存处理
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,
Change,
[Date],StoreCode,
ItemColor,Brand,Qty,AmountLC,AmountDC, ExchangeRate,
ProfitCenter,VendorAccountNumber,CreditNote, Currency)
SELECT 
getdate(), getdate(), @CurrentAPDate,
'StockinAdjustment', 
'Increase', 
am.[Date], LEFT(am.StoreCode,4),
am.ItemColor, i.Brand, isNull(am.Qty,0), am.Amount, am.Amount, '1',
am.ProfitCenter,am.VenderAccountNumber,am.Remark, @LocalCurrency
FROM Cogs_StockInAdjustment as am
LEFT JOIN Cogs_Item as i
ON i.StyleColorCode=am.ItemColor
WHERE am.APDate=@CurrentAPDate
;

-- 设置分配FLG
update Cogs_StockInAdjustment
Set AllocatedFlg = 1
FROM Cogs_StockInAdjustment
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;



--  ASN总金额乘汇率 = ItemColor金额乘汇率汇总 的差异计算入其中一个ITEM的入库调整单
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,[Date],StoreCode,
ItemColor,AmountLC,AmountDC, ExchangeRate, Currency, ASNInvoiceNo,
CreditNote)
SELECT 
getdate(), getdate(), @CurrentAPDate,
'StockinAdjustment', 'Increase', @CurrentAPDate, max(ps.StoreCode),
max(ps.ItemColor), sum(ps.AmountDC)*ps.ExchangeRate - sum(ps.AmountLC), sum(ps.AmountDC)*ps.ExchangeRate - sum(ps.AmountLC), '1', @LocalCurrency, ps.ASNInvoiceNo,
'ExchangeRate Adjustment:'+ps.ASNInvoiceNo
FROM Cogs_PurchaseSale as ps
WHERE ps.APDate=@CurrentAPDate and ps.Type='Stockin' and ps.Currency != @LocalCurrency AND ps.ASNInvoiceNo is not null
GROUP BY ps.ASNInvoiceNo, ps.ExchangeRate Having sum(ps.AmountDC)*ps.ExchangeRate - sum(ps.AmountLC) != 0
;




-- 将Cogs_PurchaseSale中的PONo，设置Cogs_LotPOInvoiceRef.AllocatedFlg=1
update lpr
Set AllocatedFlg = 1,
APDate=@CurrentAPDate
FROM Cogs_LotPOInvoiceRef lpr
WHERE lpr.LotNo IN (Select DISTINCT LotNo FROM Cogs_PurchaseSale WHERE APDate=@CurrentAPDate) 
AND AllocatedFlg !=1
;
update po
Set AllocatedFlg = 1,
APDate=@CurrentAPDate
FROM Cogs_POInvoice po
WHERE po.ASNInvoiceNo IN (Select DISTINCT ASNInvoiceNo FROM Cogs_StockIn WHERE APDate=@CurrentAPDate) 
AND AllocatedFlg !=1
;



--补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.VendorAccountNumber is null
;
--补充信息 Brand
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.Brand is null
;
--补充信息 StoreType
update Cogs_PurchaseSale
set 
StoreType=Cogs_Warehouse.StoreType
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Warehouse on Cogs_Warehouse.Code=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.StoreType is null
;




################################################   2. 结转成本分配（销售 + 库存移动）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @LocalCurrency nvarchar(50);
set @CurrentAPDate = '2019-11-1';
select @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';



-- 设置APDate对应WriteoffCostAllocated
update Cogs_APDate
set
WriteoffCostAllocated=1
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;

-- 删除 ZOO/CNBAG01-CNBAG05/R00/R08/ALT/PKG的商品的入库
delete Cogs_Sales from Cogs_Sales as si
Where si.APDate=@CurrentAPDate
AND ( si.ItemCode like '%ZOO%' OR si.ItemCode like '%CNBAG%' OR si.ItemCode like '%R00%' OR si.ItemCode like '%R08%' OR si.ItemCode like '%ALT%' OR si.ItemCode like '%PKG%' )
;

-- 清空进销存结转单
DELETE FROM Cogs_PurchaseSale where APDate=@CurrentAPDate and Change='Decrease';


-- 销售 转进销存
INSERT INTO Cogs_PurchaseSale (
CreateTime, UpdateTime, APDate, Type, Change, [Date], StoreCode,
ItemColor, Qty, Currency, ExchangeRate, SalesNetAmt, SalesRetailAmt, ProfitCenter, CreditNote)
SELECT 
getdate(), getDate(), @CurrentAPDate, sm.SalesType, 'Decrease', max(sm.SalesDate), LEFT(sm.StoreCode,4),
sm.ItemCode+sm.ColorCode, - sum(sm.Quantity), @LocalCurrency, 1, sum(sm.SalesAMT), sum(sm.RetailAMT), max(sm.ProfitCenter), max(sm.Remark)
FROM Cogs_Sales as sm
WHERE sm.APDate=@CurrentAPDate AND sm.StoreCode is not Null AND sm.Quantity != 0
GROUP BY sm.SalesType, sm.StoreCode, sm.ItemCode, sm.ColorCode
;

-- 设置分配FLG
update Cogs_Sales
Set AllocatedFlg = 1
FROM Cogs_Sales
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;




-- 删除不是本地仓库的库存移动单
delete Cogs_StockMovement from Cogs_StockMovement as si
LEFT JOIN Cogs_Warehouse as w1 ON w1.Code=si.DocumentWarehouse
LEFT JOIN Cogs_Warehouse as w2 ON w2.Code=si.RecipientWarehouse
Where w1.Code is null AND w2.Code is null  AND si.APDate=@CurrentAPDate
;
delete Cogs_StockMovementSpecial from Cogs_StockMovementSpecial as si
LEFT JOIN Cogs_Warehouse as w ON w.Code=si.Warehouse
Where w.Code is null AND si.APDate=@CurrentAPDate
;
-- 删除 ZOO/CNBAG01-CNBAG05/R00/R08/ALT/PKG的商品的入库
delete Cogs_StockMovement from Cogs_StockMovement as si
Where si.APDate=@CurrentAPDate
AND ( si.ItemCode like '%ZOO%' OR si.ItemCode like '%CNBAG%' OR si.ItemCode like '%R00%' OR si.ItemCode like '%R08%' OR si.ItemCode like '%ALT%' OR si.ItemCode like '%PKG%' )
;
delete Cogs_StockMovementSpecial from Cogs_StockMovementSpecial as si
Where si.APDate=@CurrentAPDate
AND ( si.ItemCode like '%ZOO%' OR si.ItemCode like '%CNBAG%' OR si.ItemCode like '%R00%' OR si.ItemCode like '%R08%' OR si.ItemCode like '%ALT%' OR si.ItemCode like '%PKG%' )
;

-- 处理库存移动明细默认值
update sm
set 
sm.Type = 
case 
when sm.Type is not null then sm.Type
-- when war.StoreType = 'DefectiveStore' then 'Defective'
-- when wad.StoreType = 'DefectiveStore' then 'Defective'
-- when war.StoreType = 'ImperfectionStore' then 'Imperfection'
-- when wad.StoreType = 'ImperfectionStore' then 'Imperfection'
-- when war.StoreType is null then 'inventoryLosses'
-- when wad.StoreType is null then 'inventoryProfit'
else 'SENT TRANSFER'
end
from Cogs_StockMovement as sm
LEFT JOIN Cogs_Warehouse as war on war.Code=LEFT(sm.RecipientWarehouse,4)
LEFT JOIN Cogs_Warehouse as wad on wad.Code=LEFT(sm.DocumentWarehouse,4)
WHERE sm.APDate=@CurrentAPDate And (sm.Type is null or LEN(sm.Type)<=0)
;


-- 库存移动单 转 进销存 
-- 移入一条
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,
ProfitCenter,CreditNote,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
case when LEN(isNull(sm.Type,'SENT TRANSFER'))>0 then sm.Type else 'SENT TRANSFER' end, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.RecipientWarehouse,4),
sm.ItemCode+sm.ColorCode, sum(sm.Qty),
max(sm.ProfitCenter),max(sm.Remark), max(w.StoreType)
FROM Cogs_StockMovement as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.DocumentWarehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.RecipientWarehouse)>0
GROUP BY sm.Type, sm.RecipientWarehouse, sm.ItemCode, sm.ColorCode
;
-- 移出一条
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,
ProfitCenter,CreditNote,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
case when LEN(isNull(sm.Type,'SENT TRANSFER'))>0 then sm.Type else 'SENT TRANSFER' end, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.DocumentWarehouse,4),
sm.ItemCode+sm.ColorCode, -sum(sm.Qty),
max(sm.ProfitCenter),max(sm.Remark), max(w.StoreType)
FROM Cogs_StockMovement as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.DocumentWarehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.DocumentWarehouse)>0
GROUP BY sm.Type, sm.DocumentWarehouse, sm.ItemCode, sm.ColorCode
;

-- 设置分配FLG
update Cogs_StockMovement
Set AllocatedFlg = 1
FROM Cogs_StockMovement
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;



-- StockMovementSpecial 转 进销存 
-- Special INPUT
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
sm.Type, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.Warehouse,4),
sm.ItemCode+sm.ColorCode, sum(sm.Qty), max(w.StoreType)
FROM Cogs_StockMovementSpecial as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.Warehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.Warehouse)>0 AND sm.Type='SPECIAL INPUTS'
GROUP BY sm.Type, sm.Warehouse, sm.ItemCode, sm.ColorCode
;
-- Special OUT
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
sm.Type, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.Warehouse,4),
sm.ItemCode+sm.ColorCode, -sum(sm.Qty), max(w.StoreType)
FROM Cogs_StockMovementSpecial as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.Warehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.Warehouse)>0 AND sm.Type='SPECIAL OUTPUTS'
GROUP BY sm.Type, sm.Warehouse, sm.ItemCode, sm.ColorCode
;
-- INVENTORY DISCREPANC
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
sm.Type, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.Warehouse,4),
sm.ItemCode+sm.ColorCode, sum(sm.Qty), max(w.StoreType)
FROM Cogs_StockMovementSpecial as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.Warehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.Warehouse)>0 AND sm.Type='INVENTORY DISCREPANC'
GROUP BY sm.Type, sm.Warehouse, sm.ItemCode, sm.ColorCode
;

-- 设置分配FLG
update Cogs_StockMovementSpecial
Set AllocatedFlg = 1
FROM Cogs_StockMovementSpecial
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;


--补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.VendorAccountNumber is null
;
--补充信息 Brand
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.Brand is null
;
--补充信息 StoreType
update Cogs_PurchaseSale
set 
StoreType=Cogs_Warehouse.StoreType
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Warehouse on Cogs_Warehouse.Code=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.StoreType is null
;




#################################################    3. 平均单位成本计算（期初数据生成 + 库存调整单 + 单位成本及汇总金额计算 + Markup + 减值）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @LocalCurrency nvarchar(50);
set @CurrentAPDate = '2019-11-1';
SELECT @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';


-- 设置APDate对应UnitCostingCalculated
update Cogs_APDate
set
UnitCostingCalculated=1
FROM Cogs_APDate
WHERE APDate=@CurrentAPDate
;


--------------------------------------------------------------------期初数据生成
-- 进销存明细表 期初数据生成
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate and Change='Beginning';

INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,Type,Change,[Date],StoreCode,
ItemColor,Qty,AmountDC,Currency,ExchangeRate,AmountLC)
select 
@CurrentAPDate as CreateTime, @CurrentAPDate as UpdateTime, @CurrentAPDate,'Beginning','Beginning',@CurrentAPDate,ib.StoreCode,
ib.ItemColor,Sum(Qty),Sum(Amount),@LocalCurrency,'1',Sum(Amount)
from 
Cogs_InventoryItemColor as ib
where 
APDate=DATEADD(month,-1,@CurrentAPDate)
group by 
ib.StoreCode,ib.ItemColor
;




-------------------------------------------------------------------- 库存调整单

-- 清空库存调整单数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate and Type='InventoryAdjustment'
-- 库存调整单加入进销存处理
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,APDate,
Type,
Change,
[Date],StoreCode,
ItemColor,Brand,Qty,AmountLC,AmountDC, ExchangeRate,
ProfitCenter,VendorAccountNumber,CreditNote,Currency)
SELECT 
getdate(), getdate(), @CurrentAPDate,
'InventoryAdjustment', 
'Decrease', 
am.[Date], LEFT(am.StoreCode,4),
am.ItemColor, i.Brand, isNull(am.Qty,0), isNull(am.Amount,0), isNull(am.Amount,0), 1,
am.ProfitCenter,am.VenderAccountNumber,am.Remark,@LocalCurrency
FROM Cogs_InventoryAdjustment as am
LEFT JOIN Cogs_Item as i
ON i.StyleColorCode=am.ItemColor
WHERE am.APDate=@CurrentAPDate
;

-- 设置分配FLG
update Cogs_InventoryAdjustment
Set AllocatedFlg = 1
FROM Cogs_InventoryAdjustment
WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
;



-------------------------------------------------------------------- 补充信息
--补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.VendorAccountNumber is null
;
--补充信息 Brand
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate AND Cogs_PurchaseSale.Brand is null
;
--补充信息 StoreType
update Cogs_PurchaseSale
set 
StoreType=Cogs_Warehouse.StoreType
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Warehouse on Cogs_Warehouse.Code=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.StoreType is null
;


-- 删除不是本地仓库的进销存
delete Cogs_PurchaseSale from Cogs_PurchaseSale as si
Where si.StoreType is null AND si.APDate=@CurrentAPDate
;

-------------------------------------------------------------------- 单位成本及汇总金额计算



-- 单位平均成本计算
-- 期末汇总 Cogs_InventoryItemColorSum（10月）
-- 平均单位成本 =  （期初金额 + 增加金额（本币金额+关税金额+运费金额+其他成本金额）) / （期初数量 + 增加数量）
-- 期末数量 = 期初数量 + 增加数量 + 减少数量
Delete from Cogs_InventoryItemColorSum where APDate=@CurrentAPDate
;

INSERT into Cogs_InventoryItemColorSum(CreateTime,UpdateTime, APDate, StoreType, Brand, ItemColor, UnitCost)

SELECT getdate(),getdate(),@CurrentAPDate as APDate, psa.StoreType, max(psa.Brand), psa.ItemColor
, case 
when (sum(ISNULL(psb.Qty,0)) + sum(ISNULL(psi.Qty,0))) = 0 then 0 
else (sum(ISNULL(psb.AmountLC,0)) + sum(ISNULL(psi.AmountLC,0)))/(sum(ISNULL(psb.Qty,0))+sum(ISNULL(psi.Qty,0))) 
end as UnitCost

FROM 
(
SELECT StoreType, max(Brand) as Brand, ItemColor
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate
GROUP BY StoreType, ItemColor
) as psa

LEFT JOIN
(
SELECT StoreType,ItemColor,sum(Qty) as Qty, sum(AmountLC) as AmountLC
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate AND Change='Beginning'
GROUP BY StoreType,ItemColor
) as psb
ON psb.StoreType=psa.StoreType and psb.ItemColor=psa.ItemColor

LEFT JOIN
(
SELECT StoreType,ItemColor,sum(Qty) as Qty, sum(AmountLC) as AmountLC, sum(TariffAMT) as TariffAMT, sum(FreightAMT) as FreightAMT, sum(OtherCostAMT) as OtherCostAMT
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate AND Change='Increase'
GROUP BY StoreType,ItemColor
) as psi
ON psi.StoreType=psa.StoreType and psi.ItemColor=psa.ItemColor

GROUP BY psa.StoreType, psa.ItemColor
;

-- change 12/3 tao
Update iis 
SET 
FNSeason = i.FNSeason,
RetailPrice = i.RetailPrice
FROM Cogs_InventoryItemColorSum as iis
LEFT JOIN Cogs_Item as i ON i.StyleColorCode=iis.ItemColor
where iis.APDate=@CurrentAPDate
;

-- 实际库存汇总
Update iis 
SET 
iis.StockQty = iiw.StockQty1,
iis.StockAmt = iiw.StockAmt1
FROM Cogs_InventoryItemColorSum as iis
LEFT JOIN 
(
	SELECT wa.StoreType, iic.ItemColor, sum(iic.TotalStockQty) as StockQty1, sum(iic.StockAMT) as StockAmt1
	FROM Cogs_InventoryItemColorWH as iic
	LEFT JOIN Cogs_Warehouse as wa on wa.Code=iic.StoreCode
	WHERE iic.[Date]=DATEADD(month,1,@CurrentAPDate) AND iic.TotalStockQty > 0 
	GROUP BY wa.StoreType, iic.ItemColor
) as iiw 
ON iiw.StoreType=iis.StoreType AND iiw.ItemColor=iis.ItemColor
where iis.APDate=@CurrentAPDate AND iiw.StockQty1 is not null AND iiw.StockAmt1 is not null
;



-- 计算单位成本
Update ps
set 
ps.UnitCost = iis.UnitCost
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_InventoryItemColorSum as iis ON iis.StoreType=ps.StoreType AND iis.ItemColor=ps.ItemColor AND iis.APDate=@CurrentAPDate
WHERE ps.APDate=@CurrentAPDate AND (ps.change='Increase' or ps.change='Decrease' or ps.change='Beginning') AND ps.Type != 'InventoryAdjustment' AND ps.Type != 'StockinAdjustment'
;
-- 计算移出单位成本
Update ps
set 
ps.UnitCost = iis.UnitCost
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_InventoryItemColorSum as iis ON iis.StoreType=ps.TrasferStockType AND iis.ItemColor=ps.ItemColor AND iis.APDate=@CurrentAPDate
WHERE ps.APDate=@CurrentAPDate AND ps.change='Decrease' AND LEN(ps.TrasferStockType)>0
;
-- 计算结转销帐金额
Update ps
set 
ps.AmountLC = ps.Qty * ps.UnitCost, 
ps.AmountDC = ps.Qty * ps.UnitCost
FROM Cogs_PurchaseSale as ps
WHERE ps.APDate=@CurrentAPDate AND ps.change='Decrease' AND ps.Type != 'InventoryAdjustment' AND ps.Type != 'StockinAdjustment'
;

-- 期末汇总 Cogs_InventoryItemColor
Delete from Cogs_InventoryItemColor where APDate=@CurrentAPDate;

insert into Cogs_InventoryItemColor(CreateTime,UpdateTime, APDate, StoreCode, ItemColor, Brand, FNSeason, Qty, Amount, UnitCost, RetailPrice, ProductCostAmt, InwardCostAmt, StoreType,SalesNetAmt,SalesRetailAmt)
select getdate(),getdate(),@CurrentAPDate as APDate, ps.StoreCode, ps.ItemColor, max(i.Brand), max(i.FNSeason), sum(ps.Qty),sum(ps.Qty)*max(ps.UnitCost), max(ps.UnitCost), max(i.RetailPrice), sum(ps.ProductCostAmt),sum(ps.InwardCostAmt), max(ps.StoreType),sum(ps.SalesNetAmt),sum(ps.SalesRetailAmt)
from Cogs_PurchaseSale as ps
left JOIN Cogs_Item as i on i.StyleColorCode=ps.ItemColor
where ps.APDate = @CurrentAPDate
group by ps.StoreCode,ps.ItemColor
;

-- 期末汇总 Cogs_InventoryItemColorSum 算出所有的Amount
Update iis 
SET 
Brand = psl.Brand,
Qty = psl.Qty,
Amount = psl.Amount,
ProductCostAmt = psl.ProductCostAmt,
InwardCostAmt = psl.InwardCostAmt,
SalesNetAmt = psl.SalesNetAmt,
SalesRetailAmt = psl.SalesRetailAmt
FROM Cogs_InventoryItemColorSum as iis
LEFT JOIN ( SELECT ps.StoreType as StoreType, ps.ItemColor as ItemColor, sum(isNull(ps.Qty,0)) as Qty, sum(isNull(ps.AmountLC,0)) as Amount, sum(isNull(ps.ProductCostAmt,0)) as ProductCostAmt, sum(isNull(ps.InwardCostAmt,0)) as InwardCostAmt, sum(isNull(ps.SalesNetAmt,0)) as SalesNetAmt, sum(isNull(ps.SalesRetailAmt,0)) as SalesRetailAmt
from Cogs_PurchaseSale as ps
where ps.APDate = @CurrentAPDate
group by ps.StoreType, ps.ItemColor
) as psl ON psl.StoreType=iis.StoreType AND psl.ItemColor=iis.ItemColor
where iis.APDate=@CurrentAPDate
;




-- change tao 12/2
--------------------------------------------------------------------Markup金额计算
-- Markup Ratio 取得
DECLARE @MarkupRate decimal(18,6);
SELECT @MarkupRate=Rate FROM Cogs_MarkupRate where APDate=@CurrentAPDate;


-- Markup金额计算
-- Markup Amt = （上海以外店铺）移入数量 * 单位成本 * Markup 10%
-- 上海店铺和总部不需要计算Makrup Amt，通过获取 MarkupFlg=1
Delete From Cogs_MarkupSum where APDate=@CurrentAPDate;
INSERT INTO Cogs_MarkupSum(CreateTime, UpdateTime, APDate, Type, StoreCode, ItemColor, MarkupQty, MarkupAmount)
SELECT
getdate(),getdate(),@CurrentAPDate, 'Sales', ps.StoreCode, ps.ItemColor, -sum(ps.Qty), -sum(ps.Qty)*sum(ps.UnitCost) * @MarkupRate
FROM 
Cogs_PurchaseSale as ps
LEFT JOIN Cogs_Warehouse as w ON w.Code=ps.StoreCode
WHERE ps.change='Decrease'
AND ps.APDate=@CurrentAPDate
AND w.MarkupFlg = 1 
AND ps.Qty < 0
GROUP BY ps.StoreCode, ps.ItemColor
;
INSERT INTO Cogs_MarkupSum(CreateTime, UpdateTime, APDate, Type, StoreCode, ItemColor, MarkupQty, MarkupAmount)
SELECT
getdate(),getdate(),@CurrentAPDate, 'StockMovement', ps.StoreCode, ps.ItemColor, sum(ps.Qty), sum(ps.Qty)*sum(ps.UnitCost) * @MarkupRate
FROM 
Cogs_PurchaseSale as ps
LEFT JOIN Cogs_Warehouse as w ON w.Code=ps.StoreCode
WHERE ps.change='Decrease'
AND ps.APDate=@CurrentAPDate
AND w.MarkupFlg = 1 
GROUP BY ps.StoreCode, ps.ItemColor HAVING sum(ps.Qty) > 0
;








-- change tao 12/2
--------------------------------------------------------------------减值金额计算

DECLARE @ItemImpairCnt integer;
SELECT @ItemImpairCnt=count(*) FROM Cogs_ItemImpair where APDate=@CurrentAPDate;


-- 生成减值基础数据
Delete From Cogs_ItemImpairSummary where APDate=@CurrentAPDate;
INSERT INTO Cogs_ItemImpairSummary (APDate, StoreType, Brand, FNSeason, TtlQty, TtlRetailAmt, TtlCost)
SELECT @CurrentAPDate, iis.StoreType, iis.Brand, iis.FNSeason, sum(iis.Qty), sum(iis.Qty*iis.RetailPrice), sum(iis.Amount)
FROM Cogs_InventoryItemColorSum as iis
LEFT JOIN Cogs_ItemImpair as ii ON iis.StoreType=ii.StoreType AND iis.Brand=ii.Brand AND iis.FNSeason=ii.FNSeason
WHERE iis.APDate = @CurrentAPDate AND iis.FNSeason is not null AND iis.Qty >0
GROUP BY iis.StoreType, iis.Brand, iis.FNSeason
;

-- 从减值SUM补充MST
-- Delete From Cogs_ItemImpair where APDate=@CurrentAPDate;
INSERT INTO Cogs_ItemImpair (APDate, Brand, StoreType, FNSeason, SeasonYear, ImpairType, ImpairYear)
SELECT @CurrentAPDate, iis.Brand, iis.StoreType, 
iis.FNSeason
, 
case 
when RIGHT(iis.FNSeason,2)='RE' then '20'+LEFT(iis.FNSeason,2)
when RIGHT(iis.FNSeason,2)='SP' then '20'+LEFT(iis.FNSeason,2)
when RIGHT(iis.FNSeason,2)='SU' then '20'+LEFT(iis.FNSeason,2)
when RIGHT(iis.FNSeason,2)='FA' then '20'+LEFT(iis.FNSeason,2)
when RIGHT(iis.FNSeason,2)='FW' then '20'+LEFT(iis.FNSeason,2)
when RIGHT(iis.FNSeason,2)='SS' then '20'+LEFT(iis.FNSeason,2)
else ''
end
, 
case
when iis.Brand='GWP' then 1
when iis.StoreType='DefectiveStore' then 1
when RIGHT(iis.FNSeason,2)='RE' then 2
when RIGHT(iis.FNSeason,2)='SP' then 2
when RIGHT(iis.FNSeason,2)='SU' then 2
when RIGHT(iis.FNSeason,2)='FA' then 2
when RIGHT(iis.FNSeason,2)='FW' then 2
when RIGHT(iis.FNSeason,2)='SS' then 2
else 3
end
, 3
FROM Cogs_ItemImpairSummary as iis
LEFT JOIN Cogs_ItemImpair as ii ON iis.StoreType=ii.StoreType AND iis.Brand=ii.Brand AND iis.FNSeason=ii.FNSeason
WHERE iis.APDate = @CurrentAPDate AND ii.FNSeason is null AND iis.FNSeason is not null
;

-- 减值MST计算 
UPDATE Cogs_ItemImpair 
SET
ImpairRatio = 
case 
when ii.ImpairType=1 then 1
when ii.ImpairType=2 AND ii.SeasonYear < (year(@CurrentAPDate) - ii.ImpairYear) then 1
when ii.ImpairType=2 AND ii.SeasonYear = (year(@CurrentAPDate) - ii.ImpairYear) then (convert(decimal,month(@CurrentAPDate))/12)
when ii.ImpairType=2 AND ii.SeasonYear > (year(@CurrentAPDate) - ii.ImpairYear) then 0
when ii.ImpairType=3 then 0
else 0
end
FROM Cogs_ItemImpair ii
WHERE ii.APDate = @CurrentAPDate
;

-- 减值金额计算
UPDATE Cogs_ItemImpairSummary 
SET
TtlImpairAmt = 
case 
when ii.ImpairType=1 then iis.TtlCost
when ii.ImpairType=2 then iis.TtlCost * ii.ImpairRatio
when ii.ImpairType=3 then 0
else 0
end
FROM Cogs_ItemImpairSummary iis
LEFT JOIN Cogs_ItemImpair as ii ON iis.StoreType=ii.StoreType AND iis.Brand=ii.Brand AND iis.FNSeason=ii.FNSeason
AND iis.APDate = @CurrentAPDate
;










################################################   0. 会计期间关帐     ################################################


-- TODO 检查APDate=@CurrentAPDate的Cogs_Sales,Cogs_StockMovement, Cogs_StockIn, Cogs_StockInAdjustment, Cogs_InventoryAdjustment 的AllocatedFlg=0 的数据，如果有则不能关帐

-- 




