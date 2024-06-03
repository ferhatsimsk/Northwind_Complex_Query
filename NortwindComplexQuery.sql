--Sorgu-1. Sipari�lerin Sevkiyat Gecikmelerini Hesaplayarak Raporlama
--Ama�: Sipari�lerin ne kadar s�re gecikti�ini ve bu gecikmelerin m��teri memnuniyeti �zerindeki etkisini analiz etmek.

WITH DelayedOrders AS (
    SELECT 
        o.OrderID,
        o.CustomerID,
        o.EmployeeID,
        o.OrderDate,
        o.RequiredDate,
        o.ShippedDate,
        DATEDIFF(DAY, o.RequiredDate, o.ShippedDate) AS DelayDays
    FROM 
        Orders o
    WHERE 
        o.ShippedDate IS NOT NULL AND o.RequiredDate < o.ShippedDate
)
SELECT 
    c.CompanyName,
    e.LastName AS Employee,
    AVG(DelayDays) AS AverageDelay,
    COUNT(o.OrderID) AS TotalDelayedOrders
FROM 
    DelayedOrders o
JOIN 
    Customers c ON o.CustomerID = c.CustomerID
JOIN 
    Employees e ON o.EmployeeID = e.EmployeeID
GROUP BY 
    c.CompanyName, e.LastName
ORDER BY 
    AverageDelay DESC;
	
	
--Sorgu-2. �r�n Kategorilerine G�re Ayl�k Sat�� Trendleri
--Ama�: �r�n kategorilerinin ayl�k bazda sat�� trendlerini analiz etmek.	

WITH MonthlySales AS (
    SELECT 
        p.CategoryID,
        YEAR(o.OrderDate) AS Year,
        MONTH(o.OrderDate) AS Month,
        SUM(od.Quantity * od.UnitPrice) AS TotalSales
    FROM 
        [Order Details] od
    JOIN 
        Orders o ON od.OrderID = o.OrderID
    JOIN 
        Products p ON od.ProductID = p.ProductID
    GROUP BY 
        p.CategoryID, YEAR(o.OrderDate), MONTH(o.OrderDate)
)
SELECT 
    cat.CategoryName,
    Year,
    Month,
    TotalSales
FROM 
    MonthlySales ms
JOIN 
    Categories cat ON ms.CategoryID = cat.CategoryID
ORDER BY 
    cat.CategoryName, Year, Month;

--Sorgu-3. M��terilerin Sipari� E�ilimlerini Analiz Etme
--Ama�: M��terilerin belirli zaman aral�klar�nda sipari� verme e�ilimlerini analiz etmek.

WITH OrderPatterns AS (
    SELECT 
        o.CustomerID,
        DATEPART(HOUR, o.OrderDate) AS OrderHour,
        COUNT(o.OrderID) AS OrderCount
    FROM 
        Orders o
    GROUP BY 
        o.CustomerID, DATEPART(HOUR, o.OrderDate)
)
SELECT 
    c.CompanyName,
    op.OrderHour,
    SUM(op.OrderCount) AS TotalOrders
FROM 
    OrderPatterns op
JOIN 
    Customers c ON op.CustomerID = c.CustomerID
GROUP BY 
    c.CompanyName, op.OrderHour
ORDER BY 
    TotalOrders DESC, op.OrderHour;

--Sorgu-4. �al��an Performans�n� Y�ll�k ve Ayl�k Bazda De�erlendirme
--Ama�: �al��anlar�n y�ll�k ve ayl�k bazda performans�n� de�erlendirerek, en iyi performans g�steren �al��anlar� belirlemek.

WITH EmployeePerformance AS (
    SELECT 
        e.EmployeeID,
        e.LastName,
        YEAR(o.OrderDate) AS Year,
        MONTH(o.OrderDate) AS Month,
        SUM(od.Quantity * od.UnitPrice) AS TotalSales,
        COUNT(o.OrderID) AS TotalOrders
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Employees e ON o.EmployeeID = e.EmployeeID
    GROUP BY 
        e.EmployeeID, e.LastName, YEAR(o.OrderDate), MONTH(o.OrderDate)
)
SELECT 
    EmployeeID,
    LastName,
    Year,
    Month,
    TotalSales,
    TotalOrders,
    RANK() OVER(PARTITION BY Year ORDER BY TotalSales DESC) AS YearlyRank,
    RANK() OVER(PARTITION BY Year, Month ORDER BY TotalSales DESC) AS MonthlyRank
FROM 
    EmployeePerformance
ORDER BY 
    Year, Month, TotalSales DESC;

--Sorgu-5. K�r Marj�n� Hesaplama ve �r�n Baz�nda K�r Analizi
--Ama�: �r�nlerin k�r marj�n� hesaplayarak, en k�rl� �r�nleri belirlemek.

WITH ProductProfit AS (
    SELECT 
        p.ProductID,
        p.ProductName,
        p.UnitPrice AS SellingPrice,
        SUM(od.Quantity * (od.UnitPrice - od.Discount)) AS Revenue,
        SUM(od.Quantity * (od.UnitPrice - p.UnitPrice)) AS Profit,
        AVG(od.UnitPrice - p.UnitPrice) AS AverageProfitMargin
    FROM 
        [Order Details] od
    JOIN 
        Products p ON od.ProductID = p.ProductID
    GROUP BY 
        p.ProductID, p.ProductName, p.UnitPrice
)
SELECT 
    ProductID,
    ProductName,
    SellingPrice,
    Revenue,
    Profit,
    AverageProfitMargin
FROM 
    ProductProfit
ORDER BY 
    Profit DESC;


--Sorgu-6. M��teri Segmentasyonu ve Harcama Analizi
--Ama�: M��teri segmentlerini belirleyerek, her segmentin harcama al��kanl�klar�n� analiz etmek.

WITH CustomerSpending AS (
    SELECT 
        o.CustomerID,
        c.CompanyName,
        SUM(od.Quantity * od.UnitPrice) AS TotalSpending,
        COUNT(o.OrderID) AS TotalOrders
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Customers c ON o.CustomerID = c.CustomerID
    GROUP BY 
        o.CustomerID, c.CompanyName
),
CustomerSegments AS (
    SELECT 
        CustomerID,
        CompanyName,
        TotalSpending,
        TotalOrders,
        NTILE(4) OVER (ORDER BY TotalSpending DESC) AS SpendingSegment
    FROM 
        CustomerSpending
)
SELECT 
    CompanyName,
    SpendingSegment,
    TotalSpending,
    TotalOrders
FROM 
    CustomerSegments
ORDER BY 
    SpendingSegment, TotalSpending DESC;

--Sorgu-7. Envanter Y�netimi ve Yeniden Sipari� Seviyesi Analizi
--Ama�: �r�nlerin stok seviyelerini analiz ederek, yeniden sipari� verilmesi gereken �r�nleri belirlemek.

WITH InventoryStatus AS (
    SELECT 
        p.ProductID,
        p.ProductName,
        p.UnitsInStock,
        p.ReorderLevel,
        SUM(od.Quantity) AS TotalOrdered
    FROM 
        Products p
    LEFT JOIN 
        [Order Details] od ON p.ProductID = od.ProductID
    GROUP BY 
        p.ProductID, p.ProductName, p.UnitsInStock, p.ReorderLevel
)
SELECT 
    ProductID,
    ProductName,
    UnitsInStock,
    ReorderLevel,
    TotalOrdered,
    CASE 
        WHEN UnitsInStock <= ReorderLevel THEN 'Reorder Needed'
        ELSE 'Stock Sufficient'
    END AS StockStatus
FROM 
    InventoryStatus
ORDER BY 
    StockStatus, TotalOrdered DESC;


--Sorgu-8. Tedarik�i Performans Analizi ve Ortalama Teslim S�resi
--Ama�: Tedarik�ilerin performans�n� analiz ederek, ortalama teslim s�resini hesaplamak.

WITH SupplierPerformance AS (
    SELECT 
        s.SupplierID,
        s.CompanyName,
        DATEDIFF(DAY, o.OrderDate, o.ShippedDate) AS DeliveryTime
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Products p ON od.ProductID = p.ProductID
    JOIN 
        Suppliers s ON p.SupplierID = s.SupplierID
    WHERE 
        o.ShippedDate IS NOT NULL
),
SupplierDeliveryTime AS (
    SELECT 
        SupplierID,
        CompanyName,
        AVG(DeliveryTime) AS AverageDeliveryTime,
        COUNT(*) AS TotalOrders
    FROM 
        SupplierPerformance
    GROUP BY 
        SupplierID, CompanyName
)
SELECT 
    SupplierID,
    CompanyName,
    AverageDeliveryTime,
    TotalOrders
FROM 
    SupplierDeliveryTime
ORDER BY 
    AverageDeliveryTime;


--Sorgu-9. �al��anlar�n B�lgesel Sat�� Performans�
--Ama�: �al��anlar�n farkl� b�lgelerdeki sat�� performans�n� analiz etmek.

WITH RegionalSales AS (
    SELECT 
        e.EmployeeID,
        e.LastName,
        c.Region,
        SUM(od.Quantity * od.UnitPrice) AS TotalSales
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Employees e ON o.EmployeeID = e.EmployeeID
    JOIN 
        Customers c ON o.CustomerID = c.CustomerID
    GROUP BY 
        e.EmployeeID, e.LastName, c.Region
)
SELECT 
    EmployeeID,
    LastName,
    Region,
    TotalSales,
    RANK() OVER(PARTITION BY Region ORDER BY TotalSales DESC) AS RegionalRank
FROM 
    RegionalSales
ORDER BY 
    Region, RegionalRank;


--Sorgu-10. Y�ll�k Kategori Baz�nda En �ok Sat�� Yapan �r�nler
--Ama�: Her y�l i�in kategori baz�nda en �ok sat�� yapan �r�nleri belirlemek.

WITH AnnualCategorySales AS (
    SELECT 
        p.CategoryID,
        c.CategoryName,
        p.ProductID,
        p.ProductName,
        YEAR(o.OrderDate) AS Year,
        SUM(od.Quantity * od.UnitPrice) AS TotalSales
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Products p ON od.ProductID = p.ProductID
    JOIN 
        Categories c ON p.CategoryID = c.CategoryID
    GROUP BY 
        p.CategoryID, c.CategoryName, p.ProductID, p.ProductName, YEAR(o.OrderDate)
),
RankedCategorySales AS (
    SELECT 
        CategoryID,
        CategoryName,
        ProductID,
        ProductName,
        Year,
        TotalSales,
        RANK() OVER(PARTITION BY CategoryID, Year ORDER BY TotalSales DESC) AS CategoryRank
    FROM 
        AnnualCategorySales
)
SELECT 
    CategoryID,
    CategoryName,
    ProductID,
    ProductName,
    Year,
    TotalSales,
    CategoryRank
FROM 
    RankedCategorySales
WHERE 
    CategoryRank = 1
ORDER BY 
    Year, CategoryID;
