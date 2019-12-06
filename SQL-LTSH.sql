
################################################   -1. 入库数据清空     ################################################
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';
-- 清空Cogs_PurchaseSale入库成本数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate and Change='Increase';
-- 清楚入库成本分配标识
update Cogs_StockIn set AllocatedFlg = null FROM Cogs_StockIn WHERE APDate=@CurrentAPDate;
update Cogs_StockInAdjustment set AllocatedFlg = null FROM Cogs_StockInAdjustment WHERE APDate=@CurrentAPDate
;
-- StockIn APDate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockIn as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 入库调整单 APdate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockInAdjustment as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;


################################################   -2. 结转数据清空     ################################################
DECLARE @CurrentAPDate Date;
set @CurrentAPDate = '2019-11-1';
-- 清空Cogs_PurchaseSale结转成本数据
Delete from Cogs_PurchaseSale where APDate=@CurrentAPDate AND Change='Decrease';
-- 清楚入库成本分配标识
update Cogs_Sales set AllocatedFlg = null FROM Cogs_Sales WHERE APDate=@CurrentAPDate;
update Cogs_StockMovement set AllocatedFlg = null FROM Cogs_StockMovement WHERE APDate=@CurrentAPDate;
update Cogs_InventoryAdjustment set AllocatedFlg = null FROM Cogs_InventoryAdjustment WHERE APDate=@CurrentAPDate;
-- 库存移动单 APdate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[SalesDate] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_Sales as sm
WHERE sm.[SalesDate]>=@CurrentAPDate And sm.[SalesDate]<DATEADD(month,1,@CurrentAPDate)
;
-- 库存移动单 APdate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_StockMovement as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;
-- 库存调整单 APdate矫正
update sm
set 
sm.APDate= (SELECT min(ap.APDate) FROM Cogs_APDate ap WHERE dateadd(ms,-3,DATEADD(mm,DATEDIFF(m,0,ap.APDate)+1,0)) >= sm.[Date] AND ap.Closed !=1 GROUP BY Closed)
from Cogs_InventoryAdjustment as sm
WHERE sm.[Date]>=@CurrentAPDate And sm.[Date]<DATEADD(month,1,@CurrentAPDate)
;









################################################   1. 入库成本分配（入库单+入库调整单）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @OtherCostAMT decimal;
DECLARE @LocalCurrency nvarchar(50);
DECLARE @MonthStockinQty integer

set @CurrentAPDate = '2019-11-1';
select @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';

-- 等待开启
-- 处理AllocatedFlg为空的数据调整APDate
-- update Cogs_StockIn APDate=@CurrentAPDate where AllocatedFlg != 1

-- 计算Stockin Currency
update si
SET si.Currency = v.Currency
FROM Cogs_StockIn as si
LEFT JOIN Cogs_Item as i ON i.ItemCode=si.ItemCode AND i.ColorCode=si.ColorCode
LEFT JOIN Cogs_Vendor as v ON v.VendorAccountNumber=i.VendorAccountNumber
WHERE si.ApDate=@CurrentAPDate
;

-- 更新关税表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_TariffInvoice  as tr
LEFT JOIN Cogs_LotTariffRef as ltr ON ltr.TaxBillNo = tr.TaxBillNo
WHERE tr.APDate=@CurrentAPDate;
-- 更新关税表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_FreightInvoice  as tr
LEFT JOIN Cogs_LotFreightRef as ltr ON ltr.FreightNo = tr.FreightNo AND ltr.CustomsNo = tr.CustomsNo
WHERE tr.APDate=@CurrentAPDate;
-- 更新入库表的LotNo
update tr 
set tr.LotNo = ltr.LotNo 
From Cogs_StockIn  as tr
LEFT JOIN Cogs_LotPOInvoiceRef as ltr ON ltr.StockinDocNo = tr.DocNo
WHERE tr.APDate=@CurrentAPDate;
-- 清空批次表
DELETE FROM Cogs_Lot where APDate = @CurrentAPDate;

-- 生成批次
INSERT INTO Cogs_Lot (CreateTime, UpdateTime, APDate, LotNo, TtlQty, TtlAmt, TtlTariff, TtlTax, TtlFreightAmt, TtlStockQty, TtlStockAmt)
SELECT lir.CreateTime, lir.UpdateTime, @CurrentAPDate, lir.LotNo, lir.TtlQty, lir.TtlAmt, tr1.TtlTariff, tr2.TtlTax, fr.TtlFreightAmt, lir.TtlQty, lir.TtlAmt
FROM (SELECT max(CreateTime) as CreateTime,max(UpdateTime) as UpdateTime,LotNo, sum(Qty) as TtlQty, sum(Qty*UnitPrice) as TtlAmt FROM Cogs_StockIn WHERE APDate=@CurrentAPDate GROUP BY LotNo) as lir
LEFT JOIN (SELECT LotNo, sum(PayAmount) as TtlTariff FROM Cogs_TariffInvoice WHERE TaxType='01' GROUP BY LotNo) as tr1 ON tr1.LotNo=lir.LotNo
LEFT JOIN (SELECT LotNo, sum(PayAmount) as TtlTax FROM Cogs_TariffInvoice WHERE TaxType='02' GROUP BY LotNo) as tr2 ON tr2.LotNo=lir.LotNo
LEFT JOIN (SELECT LotNo, sum(Amount) as TtlFreightAmt FROM Cogs_FreightInvoice GROUP BY LotNo) as fr ON fr.LotNo=lir.LotNo
WHERE lir.LotNo is not null


-- 生成当月其他费用汇总
select @OtherCostAMT = sum(Amount) From Cogs_OtherFeeInvoice Where APDate=@CurrentAPDate;
select @MonthStockinQty = sum(Qty) From Cogs_StockIn Where APDate=@CurrentAPDate;

-- 清空进销存入库单
DELETE FROM Cogs_PurchaseSale where ApDate=@CurrentAPDate and Type='Stockin';

-- 入库单 转进销存
INSERT INTO Cogs_PurchaseSale (
CreateTime,UpdateTime,ApDate,Type,Change,[Date],StoreCode,
ItemColor,Qty,AmountDC,Currency, ExchangeRate,
LotNo, TariffAMT, FreightAMT, OtherCostAMT)
SELECT 
getdate(), getDate(), @CurrentAPDate, 'Stockin', 'Increase', max(sm.[Date]), LEFT(sm.Location,4),
sm.ItemCode+sm.ColorCode, sum(sm.Qty), sum(sm.Qty*sm.UnitPrice), sm.Currency, max(er.Rate), 
sm.LotNo, max(lt.TtlTariff)/max(lt.TtlStockAmt)*sum(sm.Qty*sm.UnitPrice), max(lt.TtlFreightAmt)/max(lt.TtlStockQty)*sum(sm.Qty), @OtherCostAMT/@MonthStockinQty*sum(sm.Qty)
FROM Cogs_StockIn as sm
LEFT JOIN Cogs_ExchangeRate as er ON er.FromCurrency = sm.Currency and er.ToCurrency=@LocalCurrency AND er.APDate=@CurrentAPDate
LEFT JOIN Cogs_Lot as lt ON lt.LotNo = sm.LotNo AND lt.LotNo is not null
WHERE sm.APDate=@CurrentAPDate AND sm.Location is not Null
GROUP BY sm.LotNo, sm.Currency, sm.Location, sm.ItemCode, sm.ColorCode
;

-- TODO 需要开启
-- 设置分配FLG
--update Cogs_StockIn
--Set AllocatedFlg = 1
--FROM Cogs_StockIn
--WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
--;

-- --补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='Stockin'
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand,
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='Stockin'
;






----------------------------------------------入库调整单

-- 等待开启
-- 处理AllocatedFlg为空的数据调整APDate
-- update Cogs_StockInAdjustment APDate=@CurrentAPDate where AllocatedFlg != 1


-- 清空入库调整单数据
Delete from Cogs_PurchaseSale where ApDate=@CurrentAPDate and Type='StockinAdjustment';
-- 库存调整单加入进销存处理
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,ApDate,
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

-- TODO 需要开启
-- 设置分配FLG
--update Cogs_StockInAdjustment
--Set AllocatedFlg = 1
--FROM Cogs_StockIn
--WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
--;

-- --补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='StockinAdjustment' and Cogs_PurchaseSale.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand,
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='StockinAdjustment' and Cogs_PurchaseSale.VendorAccountNumber is null
;
--补充信息 Brand
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='StockinAdjustment' and Cogs_PurchaseSale.Brand is null
;





################################################   2. 结转成本分配（销售 + 库存移动）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @LocalCurrency nvarchar(50);
set @CurrentAPDate = '2019-11-1';
select @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';

-- 等待开启
-- 处理AllocatedFlg为空的数据调整APDate
-- update Cogs_Sales APDate=@CurrentAPDate where AllocatedFlg != 1

-- 清空进销存结转单
DELETE FROM Cogs_PurchaseSale where ApDate=@CurrentAPDate and Change='Decrease';


-- 销售 转进销存
INSERT INTO Cogs_PurchaseSale (
CreateTime, UpdateTime, ApDate, Type, Change, [Date], StoreCode,
ItemColor, Qty, Currency, ExchangeRate, SalesAmt, RetailAmt, ProfitCenter, CreditNote)
SELECT 
getdate(), getDate(), @CurrentAPDate, sm.SalesType, 'Decrease', max(sm.SalesDate), LEFT(sm.StoreCode,4),
sm.ItemCode+sm.ColorCode, - sum(sm.Quantity), @LocalCurrency, 1, sum(sm.SalesAMT), sum(sm.RetailAMT), max(sm.ProfitCenter), max(sm.Remark)
FROM Cogs_Sales as sm
WHERE sm.APDate=@CurrentAPDate AND sm.StoreCode is not Null AND sm.Quantity != 0
GROUP BY sm.SalesType, sm.StoreCode, sm.ItemCode, sm.ColorCode
;

-- TODO 需要开启
-- 设置分配FLG
--update Cogs_StockIn
--Set AllocatedFlg = 1
--FROM Cogs_Sales
--WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
--;

-- --补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='Stockin'
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand,
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and Cogs_PurchaseSale.Type='Stockin'
;






-- 等待开启
-- 处理AllocatedFlg为空的数据调整APDate
-- update Cogs_StockMovement APDate=@CurrentAPDate where AllocatedFlg != 1

-- 处理库存移动明细默认值
update sm
set 
sm.Type = 
case 
when sm.Type is not null then sm.Type
when war.StoreType = 'DefectiveStore' then 'Defective'
when wad.StoreType = 'DefectiveStore' then 'Defective'
when war.StoreType = 'ImperfectionStore' then 'Imperfection'
when wad.StoreType = 'ImperfectionStore' then 'Imperfection'
when war.StoreType is null then 'inventoryLosses'
when wad.StoreType is null then 'inventoryProfit'
else 'StockMovement'
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
CreateTime,UpdateTime,ApDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,
ProfitCenter,CreditNote,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
case when LEN(isNull(sm.Type,'StockMovement'))>0 then sm.Type else 'StockMovement' end, 'Decrease',@LocalCurrency,'1',
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
CreateTime,UpdateTime,ApDate,
Type,Change,Currency,ExchangeRate,
[Date],StoreCode,ItemColor,Qty,
ProfitCenter,CreditNote,TrasferStockType)
SELECT 
getdate(), getdate(), @CurrentAPDate,
case when LEN(isNull(sm.Type,'StockMovement'))>0 then sm.Type else 'StockMovement' end, 'Decrease',@LocalCurrency,'1',
max(sm.[Date]), LEFT(sm.DocumentWarehouse,4),
sm.ItemCode+sm.ColorCode, -sum(sm.Qty),
max(sm.ProfitCenter),max(sm.Remark), max(w.StoreType)
FROM Cogs_StockMovement as sm
LEFT JOIN Cogs_Warehouse as w ON w.Code=sm.DocumentWarehouse
WHERE sm.APDate=@CurrentAPDate AND LEN(sm.DocumentWarehouse)>0
GROUP BY sm.Type, sm.DocumentWarehouse, sm.ItemCode, sm.ColorCode
;

-- TODO 需要开启
-- 设置分配FLG
--update Cogs_StockIn
--Set AllocatedFlg = 1
--FROM Cogs_StockMovement
--WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
--;


--补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=pc.ProfitCenter
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_ProfitCenter as pc
ON pc.StoreCode=ps.StoreCode
where ps.APDate=@CurrentAPDate AND ps.Change='Decrease' and ps.Type!='InventoryAdjustment' and ps.Type!='StockinAdjustment' and ps.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
Brand=i.Brand,
VendorAccountNumber=i.VendorAccountNumber
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_Item as i
ON i.StyleColorCode=ps.ItemColor
where ps.APDate=@CurrentAPDate AND ps.Change='Decrease' and ps.Type!='InventoryAdjustment' and ps.Type!='StockinAdjustment' and (ps.VendorAccountNumber is null or ps.Brand is null)
;







#################################################    3. 平均单位成本计算（期初数据生成 + 库存调整单 + 单位成本及汇总金额计算 + Markup + 减值）     ################################################
DECLARE @CurrentAPDate Date;
DECLARE @LocalCurrency nvarchar(50);
set @CurrentAPDate = '2019-11-1';
SELECT @LocalCurrency = [value] From Cogs_SearchOption Where [key]='LocalCurrency';


--------------------------------------------------------------------期初数据生成
-- 进销存明细表 期初数据生成
Delete from Cogs_PurchaseSale where ApDate=@CurrentAPDate and Change='Beginning';

INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,ApDate,Type,Change,[Date],StoreCode,
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

--补充信息
update Cogs_PurchaseSale
set 
ProfitCenter=pc.ProfitCenter,
Brand=i.Brand,
VendorAccountNumber=i.VendorAccountNumber
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_ProfitCenter as pc
ON pc.StoreCode=ps.StoreCode
LEFT JOIN Cogs_Item as i
ON i.StyleColorCode=ps.ItemColor
where ps.APDate=@CurrentAPDate AND ps.Change='Beginning'
;



-------------------------------------------------------------------- 等待开启
-- 处理AllocatedFlg为空的数据调整APDate
-- update Cogs_InventoryAdjustment APDate=@CurrentAPDate where AllocatedFlg != 1



-------------------------------------------------------------------- 库存调整单

-- 清空库存调整单数据
Delete from Cogs_PurchaseSale where ApDate=@CurrentAPDate and Type='InventoryAdjustment'
-- 库存调整单加入进销存处理
INSERT INTO 
Cogs_PurchaseSale(
CreateTime,UpdateTime,ApDate,
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

-- TODO 需要开启
-- 设置分配FLG
--update Cogs_InventoryAdjustment
--Set AllocatedFlg = 1
--FROM Cogs_Sales
--WHERE APDate=@CurrentAPDate AND AllocatedFlg != 1
--;

-- --补充信息 ProfitCenter
update Cogs_PurchaseSale
set 
ProfitCenter=Cogs_ProfitCenter.ProfitCenter
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_ProfitCenter
ON Cogs_ProfitCenter.StoreCode=Cogs_PurchaseSale.StoreCode
where Cogs_PurchaseSale.APDate=@CurrentAPDate and (Cogs_PurchaseSale.Type='InventoryAdjustment' or Cogs_PurchaseSale.Type='StockinAdjustment') and Cogs_PurchaseSale.ProfitCenter is null
;
--补充信息 VendorAccountNumber
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand,
VendorAccountNumber=Cogs_Item.VendorAccountNumber
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and (Cogs_PurchaseSale.Type='InventoryAdjustment' or Cogs_PurchaseSale.Type='StockinAdjustment') and Cogs_PurchaseSale.VendorAccountNumber is null
;
--补充信息 Brand
update Cogs_PurchaseSale
set 
Brand=Cogs_Item.Brand
FROM Cogs_PurchaseSale
LEFT JOIN Cogs_Item
ON Cogs_Item.StyleColorCode=Cogs_PurchaseSale.ItemColor
where Cogs_PurchaseSale.APDate=@CurrentAPDate and (Cogs_PurchaseSale.Type='InventoryAdjustment' or Cogs_PurchaseSale.Type='StockinAdjustment') and Cogs_PurchaseSale.Brand is null
;




-------------------------------------------------------------------- 单位成本及汇总金额计算

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


-- 单位平均成本计算
-- 期末汇总 Cogs_InventoryItemColorSum（10月）
-- 平均单位成本 =  （期初金额 + 增加金额（本币金额+关税金额+运费金额+其他成本金额）) / （期初数量 + 增加数量）
-- 期末数量 = 期初数量 + 增加数量 + 减少数量
Delete from Cogs_InventoryItemColorSum where ApDate=@CurrentAPDate
;

INSERT into Cogs_InventoryItemColorSum(CreateTime,UpdateTime, APDate, StoreType, ItemColor, Qty, UnitCost)

SELECT getdate(),getdate(),@CurrentAPDate as APDate, wa.StoreType, psa.ItemColor
,( ISNULL(sum(psb.Qty),0) + ISNULL(sum(psi.Qty),0) + ISNULL(sum(psd.Qty),0) ) as Qty
, case 
when (sum(ISNULL(psb.Qty,0)) + sum(ISNULL(psi.Qty,0))) = 0 then 0 
else (sum(ISNULL(psb.AmountLC,0)) + sum(ISNULL(psi.AmountLC,0)))/(sum(ISNULL(psb.Qty,0))+sum(ISNULL(psi.Qty,0))) 
end as UnitCost

FROM 
(
SELECT StoreCode,ItemColor
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate
GROUP BY StoreCode,ItemColor
) as psa

LEFT JOIN
(
SELECT StoreCode,ItemColor,sum(Qty) as Qty, sum(AmountLC) as AmountLC
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate AND Change='Beginning'
GROUP BY StoreCode,ItemColor
) as psb
ON psb.StoreCode=psa.StoreCode and psb.ItemColor=psa.ItemColor

LEFT JOIN
(
SELECT StoreCode,ItemColor,sum(Qty) as Qty, sum(AmountLC) as AmountLC
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate AND Change='Decrease'
GROUP BY StoreCode,ItemColor
) as psd
ON psd.StoreCode=psa.StoreCode and psd.ItemColor=psa.ItemColor

LEFT JOIN
(
SELECT StoreCode,ItemColor,sum(Qty) as Qty, sum(AmountLC) as AmountLC, sum(TariffAMT) as TariffAMT, sum(FreightAMT) as FreightAMT, sum(OtherCostAMT) as OtherCostAMT
FROM Cogs_PurchaseSale
WHERE APDate=@CurrentAPDate AND Change='Increase'
GROUP BY StoreCode,ItemColor
) as psi
ON psi.StoreCode=psa.StoreCode and psi.ItemColor=psa.ItemColor

LEFT JOIN Cogs_Warehouse as wa on wa.Code=psa.StoreCode
WHERE wa.StoreType != 'NotUsed'
GROUP BY wa.StoreType, psa.ItemColor
;

Update iis 
SET 
Brand = i.Brand
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



-- 进销存 结转数据 计算Amount金额 
Update ps
set 
ps.UnitCost = iis.UnitCost
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_Warehouse as wa on wa.Code=ps.StoreCode
LEFT JOIN Cogs_InventoryItemColorSum as iis ON iis.StoreType=wa.StoreType AND iis.ItemColor=ps.ItemColor AND iis.APDate=@CurrentAPDate
WHERE ps.APDate=@CurrentAPDate AND (ps.change='Increase' or ps.change='Decrease') AND ps.Type != 'InventoryAdjustment' AND ps.Type != 'StockinAdjustment'
;

Update ps
set 
ps.UnitCost = iis.UnitCost
FROM Cogs_PurchaseSale as ps
LEFT JOIN Cogs_InventoryItemColorSum as iis ON iis.StoreType=ps.TrasferStockType AND iis.ItemColor=ps.ItemColor AND iis.APDate=@CurrentAPDate
WHERE ps.APDate=@CurrentAPDate AND ps.Type = 'StockMovement' AND LEN(ps.TrasferStockType)>0
;

Update ps
set 
ps.AmountLC = ps.Qty * ps.UnitCost, 
ps.AmountDC = ps.Qty * ps.UnitCost
FROM Cogs_PurchaseSale as ps
WHERE ps.APDate=@CurrentAPDate AND ps.change='Decrease' AND ps.Type != 'InventoryAdjustment' AND ps.Type != 'StockinAdjustment'
;

-- 期末汇总 Cogs_InventoryItemColor
Delete from Cogs_InventoryItemColor where ApDate=@CurrentAPDate;

insert into Cogs_InventoryItemColor(CreateTime,UpdateTime, APDate, StoreCode, ItemColor, Brand, Qty, Amount, UnitCost)
select getdate(),getdate(),@CurrentAPDate as APDate, ps.StoreCode, ps.ItemColor, max(i.Brand), sum(ps.Qty), 
sum(isNull(ps.AmountLC,0)), max(ps.UnitCost)
from Cogs_PurchaseSale as ps
left JOIN Cogs_Item as i on i.StyleColorCode=ps.ItemColor
where ps.APDate = @CurrentAPDate
group by ps.StoreCode,ps.ItemColor
;

-- 期末汇总 Cogs_InventoryItemColorSum 算出所有的Amount
Update iis 
SET 
Qty = psl.Qty,
Amount = psl.Amount
FROM Cogs_InventoryItemColorSum as iis
LEFT JOIN ( SELECT w.StoreType as StoreType, ps.ItemColor as ItemColor, sum(isNull(ps.Qty,0)) as Qty, sum(isNull(ps.AmountLC,0)) as Amount
from Cogs_PurchaseSale as ps
left JOIN Cogs_Warehouse as w on w.Code=ps.StoreCode
where ps.APDate = @CurrentAPDate
group by w.StoreType, ps.ItemColor
) as psl ON psl.StoreType=iis.StoreType AND psl.ItemColor=iis.ItemColor
where iis.APDate=@CurrentAPDate
;




--------------------------------------------------------------------Markup金额计算


-- Markup金额计算（10月）
-- Markup Amt = （上海以外店铺）移入数量 * 单位成本 * Markup 10%
-- 上海店铺和总部不需要计算Makrup Amt，通过获取 City!=Shanghai/HQ的StoreCode  
DECLARE @MarkupRate decimal(18,4);
SELECT @MarkupRate=Rate FROM Cogs_MarkupRate where APDate=@CurrentAPDate;

Delete From Cogs_MarkupSum where APDate=@CurrentAPDate;
INSERT INTO Cogs_MarkupSum(CreateTime, UpdateTime, APDate, StoreCode, ItemColor, MarkupQty, MarkupAmount)
SELECT
getdate(),getdate(),@CurrentAPDate, ps.StoreCode, ps.ItemColor, ps.Qty, ps.AmountLC * @MarkupRate
FROM 
Cogs_PurchaseSale as ps
LEFT JOIN Cogs_Warehouse as w ON w.Code=ps.StoreCode
WHERE ps.Type='StockMovement'
AND ps.APDate=@CurrentAPDate
AND CHARINDEX('Shanghai',w.City)>=0 And w.City != 'HQ'
AND ps.Qty > 0
;







--------------------------------------------------------------------减值金额计算




-- TODO
-- 期末减值金额计算（10月）
-- INSERT INTO Cogs_ImpairmentSummary (APDate, StoreType, Brand, FNSeason, TtlQty, TtlRetailAmt, TtlCost, TtlImpairmentAmt)
-- SELECT iis.StoreType, iis.Brand, i.FNSeason, sum(iis.Qty), sum(iis.Qty)*i.RetailPrice, sum(iis.Amount), 
-- case 
-- when ii.ImpairmentType=1 then sum(iis.Qty) * i.RetailPrice
-- when ii.ImpairmentType=2 AND then sum(iis.Qty) * i.RetailPrice * ii.ImpairmentRatio
-- else 0
-- end
-- FROM Cogs_InventoryItemColorSum as iis
-- LEFT JOIN Cogs_Item as i ON i.StyleColorCode=iis.ItemColor
-- LEFT JOIN Cogs_ItemImpair as ii ON iis.StoreType=ii.StoreType AND iis.Brand=ii.Brand AND i.FNSeason=ii.FNSeason
-- WHERE iis.APDate=@CurrentAPDate
-- GROUP BY iis.StoreType, iis.Brand, i.FNSeason
-- ;

-- -- 本期减值差值计算（10月）
-- SELECT 
-- isa.StoreType, isa.Brand, isa.FNSeason, isa.TtlQty, isa.TtlRetailAmt, isa.TtlCost, isa.TtlImpairmentAmt - isb.TtlImpairmentAmt
-- FROM Cogs_ImpairmentSummary as isa
-- LEFT JOIN Cogs_ImpairmentSummary as isb ON isb.APDate=DATEADD(month,1,@CurrentAPDate) isa.StoreType=isb.StoreType AND isa.Brand=isb.Brand AND isa.FNSeason=isb.FNSeason
-- WHERE iis.APDate=@CurrentAPDate
-- ;












