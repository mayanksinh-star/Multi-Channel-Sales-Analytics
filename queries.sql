--Q1 List of customers who have never placed an order
SELECT 
    c._CustomerID,
    c.CustomerName
FROM Dim_Customers c
LEFT JOIN FactTable f ON c._CustomerID = f._CustomerID
WHERE f.OrderNumber IS NULL;


-- Q2 Find all orders where delivery took more than 15 days
SELECT 
    OrderNumber,
    OrderDate,
    DeliveryDate,
    (DeliveryDate - OrderDate) AS DeliveryDays
FROM FactTable
WHERE (DeliveryDate - OrderDate) > 15
ORDER BY DeliveryDays DESC;


-- Q3 Rank sales reps by total revenue within each region 
SELECT 
    s.SalesTeam,
    s.Region,
    ROUND(SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)), 2) AS TotalRevenue,
    RANK() OVER (
        PARTITION BY s.Region 
        ORDER BY SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) DESC
    ) AS RegionRank
FROM FactTable f
JOIN Dim_SalesTeams s ON f._SalesTeamID = s._SalesTeamID
GROUP BY s.SalesTeam, s.Region
ORDER BY s.Region, RegionRank;


-- Q4 Show each product's revenue and percentage contribution to total revenue
WITH ProductRevenue AS (
    SELECT 
        f._ProductID,
        SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) AS ProductRevenue
    FROM FactTable f
    GROUP BY f._ProductID
),
TotalRev AS (
    SELECT SUM(ProductRevenue) AS Total FROM ProductRevenue
)
SELECT 
    p.ProductName,
    ROUND(pr.ProductRevenue, 2) AS Revenue,
    ROUND(pr.ProductRevenue / tr.Total * 100, 2) AS PctOfTotal
FROM ProductRevenue pr
JOIN Dim_Products p ON pr._ProductID = p._ProductID
CROSS JOIN TotalRev tr
ORDER BY Revenue DESC;


-- Q5 Find the top 3 customers by revenue in each region
WITH CustomerRevenue AS (
    SELECT 
        f._CustomerID,
        s.Region,
        SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) AS Revenue
    FROM FactTable f
    JOIN Dim_SalesTeams s ON f._SalesTeamID = s._SalesTeamID
    GROUP BY f._CustomerID, s.Region
),
Ranked AS (
    SELECT 
        _CustomerID,
        Region,
        Revenue,
        RANK() OVER (PARTITION BY Region ORDER BY Revenue DESC) AS rnk
    FROM CustomerRevenue
)
SELECT 
    c.CustomerName,
    r.Region,
    ROUND(r.Revenue, 2) AS Revenue,
    r.rnk AS RegionRank
FROM Ranked r
JOIN Dim_Customers c ON r._CustomerID = c._CustomerID
WHERE r.rnk <= 3
ORDER BY r.Region, r.rnk;


-- Q6 Calculate running total of revenue order by order date
SELECT 
    OrderDate,
    OrderNumber,
    ROUND(OrderQuantity * UnitPrice * (1 - DiscountApplied), 2) AS OrderRevenue,
    ROUND(SUM(OrderQuantity * UnitPrice * (1 - DiscountApplied)) 
          OVER (ORDER BY OrderDate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS RunningRevenue
FROM FactTable
ORDER BY OrderDate;


-- Q7 Profit margin percentage per product - flag products below 20% margin
SELECT 
    p.ProductName,
    ROUND(SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)), 2) AS Revenue,
    ROUND(SUM(f.OrderQuantity * f.UnitCost), 2) AS TotalCost,
    ROUND(
        SUM(f.OrderQuantity * (f.UnitPrice * (1 - f.DiscountApplied) - f.UnitCost)) /
        NULLIF(SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)), 0) * 100, 2
    ) AS ProfitMarginPct,
    CASE 
        WHEN SUM(f.OrderQuantity * (f.UnitPrice * (1 - f.DiscountApplied) - f.UnitCost)) /
             NULLIF(SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)), 0) < 0.20
        THEN 'Low Margin'
        ELSE 'Healthy'
    END AS MarginStatus
FROM FactTable f
JOIN Dim_Products p ON f._ProductID = p._ProductID
GROUP BY p.ProductName
ORDER BY ProfitMarginPct ASC;


-- Q8 Sales performance by store population segment
SELECT 
    CASE 
        WHEN sl.Population >= 500000 THEN 'Large City'
        WHEN sl.Population >= 150000 THEN 'Mid-Size City'
        ELSE 'Small City'
    END AS CitySegment,
    COUNT(DISTINCT sl._StoreID) AS StoreCount,
    COUNT(f.OrderNumber) AS TotalOrders,
    ROUND(SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)), 2) AS TotalRevenue
FROM FactTable f
JOIN Dim_Store_location sl ON f._StoreID = sl._StoreID
GROUP BY CitySegment
ORDER BY TotalRevenue DESC;


-- Q9 Top product per region by revenue
WITH RegionProductRevenue AS (
    SELECT 
        s.Region,
        p.ProductName,
        SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) AS Revenue,
        RANK() OVER (
            PARTITION BY s.Region 
            ORDER BY SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) DESC
        ) AS rnk
    FROM FactTable f
    JOIN Dim_SalesTeams s ON f._SalesTeamID = s._SalesTeamID
    JOIN Dim_Products p   ON f._ProductID   = p._ProductID
    GROUP BY s.Region, p.ProductName
)
SELECT 
    Region,
    ProductName,
    ROUND(Revenue, 2) AS Revenue
FROM RegionProductRevenue
WHERE rnk = 1
ORDER BY Region;


-- Q10 Identify repeat customers vs one-time customers
SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-Time Customer'
        WHEN order_count BETWEEN 2 AND 5 THEN 'Occasional Customer'
        ELSE 'Loyal Customer'
    END AS CustomerSegment,
    COUNT(*) AS CustomerCount
FROM (
    SELECT _CustomerID, COUNT(OrderNumber) AS order_count
    FROM FactTable
    GROUP BY _CustomerID
) sub
GROUP BY CustomerSegment
ORDER BY CustomerCount DESC;


-- Q11 Product-level performance scorecard: revenue rank, profit margin tier, and discount sensitivity
WITH ProductMetrics AS (
    SELECT 
        p._ProductID,
        p.ProductName,
        SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied))                  AS Revenue,
        SUM(f.OrderQuantity * (f.UnitPrice * (1 - f.DiscountApplied) - f.UnitCost))  AS Profit,
        AVG(f.DiscountApplied)                                                        AS AvgDiscount,
        COUNT(f.OrderNumber)                                                          AS OrderCount
    FROM FactTable f
    JOIN Dim_Products p ON f._ProductID = p._ProductID
    GROUP BY p._ProductID, p.ProductName
)
SELECT 
    ProductName,
    ROUND(Revenue, 2) AS Revenue,
    RANK() OVER (ORDER BY Revenue DESC) AS RevenueRank,
    ROUND(Profit / NULLIF(Revenue, 0) * 100, 2) AS MarginPct,
    CASE 
        WHEN Profit / NULLIF(Revenue, 0) >= 0.30 THEN 'High Margin'
        WHEN Profit / NULLIF(Revenue, 0) >= 0.15 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS MarginTier,
    ROUND(AvgDiscount * 100, 2) AS AvgDiscountPct,
    CASE 
        WHEN AvgDiscount > (SELECT AVG(DiscountApplied) FROM FactTable) THEN 'Above Avg Discount'
        ELSE 'Below Avg Discount'
    END AS DiscountFlag
FROM ProductMetrics
ORDER BY RevenueRank;


-- Q12 Store-level scorecard combining demographic dimension data, sales performance, and regional benchmarking
WITH StoreSales AS (
    SELECT 
        sl._StoreID,
        sl.CityName,
        sl.State,
        sl.Population,
        sl.MedianIncome,
        r.Region,
        SUM(f.OrderQuantity * f.UnitPrice * (1 - f.DiscountApplied)) AS StoreRevenue,
        COUNT(f.OrderNumber) AS OrderCount
    FROM FactTable f
    JOIN Dim_Store_location sl ON f._StoreID = sl._StoreID
    JOIN Dim_Regions r ON sl.StateCode = r.StateCode
    GROUP BY sl._StoreID, sl.CityName, sl.State, sl.Population, sl.MedianIncome, r.Region
)
SELECT 
    CityName,
    State,
    Region,
    Population,
    MedianIncome,
    ROUND(StoreRevenue, 2) AS StoreRevenue,
    ROUND(AVG(StoreRevenue) OVER (PARTITION BY Region), 2) AS RegionAvgRevenue,
    CASE 
        WHEN StoreRevenue > AVG(StoreRevenue) OVER (PARTITION BY Region) THEN 'Above Region Avg'
        ELSE 'Below Region Avg'
    END AS PerformanceFlag,
    ROUND(StoreRevenue / NULLIF(Population, 0) * 1000, 2) AS RevenuePer1000Pop
FROM StoreSales
ORDER BY Region, StoreRevenue DESC;






































