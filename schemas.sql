-- ============================================================
-- DATABASE SCHEMA — Sales Analytics Star Schema
-- Dialect: PostgreSQL
-- Order of creation: Dimensions first, then Fact (FK dependency)
-- ============================================================

-- ============================================================
-- 1. Dim_Customers
-- ============================================================
DROP TABLE IF EXISTS Dim_Customers CASCADE;

CREATE TABLE Dim_Customers (
    _CustomerID     INTEGER PRIMARY KEY,
    CustomerName    VARCHAR(150) NOT NULL
);

-- ============================================================
-- 2. Dim_Products
-- ============================================================
DROP TABLE IF EXISTS Dim_Products CASCADE;

CREATE TABLE Dim_Products (
    _ProductID      INTEGER PRIMARY KEY,
    ProductName     VARCHAR(150) NOT NULL
);

-- ============================================================
-- 3. Dim_Regions
-- ============================================================
DROP TABLE IF EXISTS Dim_Regions CASCADE;

CREATE TABLE Dim_Regions (
    StateCode       VARCHAR(10) PRIMARY KEY,
    State           VARCHAR(100) NOT NULL,
    Region          VARCHAR(50)  NOT NULL
);

-- ============================================================
-- 4. Dim_SalesTeams
-- ============================================================
DROP TABLE IF EXISTS Dim_SalesTeams CASCADE;

CREATE TABLE Dim_SalesTeams (
    _SalesTeamID    INTEGER PRIMARY KEY,
    SalesTeam       VARCHAR(150) NOT NULL,
    Region          VARCHAR(50)
);

-- ============================================================
-- 5. Dim_Store_location
-- ============================================================
DROP TABLE IF EXISTS Dim_Store_location CASCADE;

CREATE TABLE Dim_Store_location (
    _StoreID        INTEGER PRIMARY KEY,
    CityName        VARCHAR(100),
    County          VARCHAR(100),
    StateCode       VARCHAR(10),
    State           VARCHAR(100),
    Type            VARCHAR(50),
    Latitude        NUMERIC(9,6),
    Longitude       NUMERIC(9,6),
    AreaCode        VARCHAR(20),
    Population      INTEGER,
    HouseholdIncome NUMERIC(12,2),
    MedianIncome    NUMERIC(12,2),
    LandArea        NUMERIC(15,2),
    WaterArea       NUMERIC(15,2),
    TimeZone        VARCHAR(50),

    CONSTRAINT fk_store_state FOREIGN KEY (StateCode)
        REFERENCES Dim_Regions (StateCode)
);

-- ============================================================
-- 6. FactTable (Sales Orders)
-- ============================================================
DROP TABLE IF EXISTS FactTable CASCADE;

CREATE TABLE FactTable (
    OrderNumber       VARCHAR(30) PRIMARY KEY,
    SalesChannel      VARCHAR(50),
    WarehouseCode     VARCHAR(30),
    ProcuredDate      DATE,
    OrderDate         DATE,
    ShipDate          DATE,
    DeliveryDate      DATE,
    CurrencyCode      VARCHAR(10),
    _SalesTeamID      INTEGER,
    _CustomerID       INTEGER,
    _StoreID          INTEGER,
    _ProductID        INTEGER,
    OrderQuantity     INTEGER       NOT NULL CHECK (OrderQuantity >= 0),
    DiscountApplied   NUMERIC(5,4)  NOT NULL CHECK (DiscountApplied BETWEEN 0 AND 1),
    UnitPrice         NUMERIC(12,2) NOT NULL CHECK (UnitPrice >= 0),
    UnitCost          NUMERIC(12,2) NOT NULL CHECK (UnitCost >= 0),

    CONSTRAINT fk_fact_salesteam FOREIGN KEY (_SalesTeamID)
        REFERENCES Dim_SalesTeams (_SalesTeamID),
    CONSTRAINT fk_fact_customer FOREIGN KEY (_CustomerID)
        REFERENCES Dim_Customers (_CustomerID),
    CONSTRAINT fk_fact_store FOREIGN KEY (_StoreID)
        REFERENCES Dim_Store_location (_StoreID),
    CONSTRAINT fk_fact_product FOREIGN KEY (_ProductID)
        REFERENCES Dim_Products (_ProductID)
);

-- ============================================================
-- Indexes for query performance (foreign keys + common filters)
-- ============================================================
CREATE INDEX idx_fact_customerid   ON FactTable (_CustomerID);
CREATE INDEX idx_fact_productid    ON FactTable (_ProductID);
CREATE INDEX idx_fact_salesteamid  ON FactTable (_SalesTeamID);
CREATE INDEX idx_fact_storeid      ON FactTable (_StoreID);
CREATE INDEX idx_fact_orderdate    ON FactTable (OrderDate);
CREATE INDEX idx_fact_saleschannel ON FactTable (SalesChannel);

CREATE INDEX idx_store_statecode   ON Dim_Store_location (StateCode);

-- ============================================================
-- (Optional) Verify structure after creation
-- ============================================================
-- \d Dim_Customers
-- \d Dim_Products
-- \d Dim_Regions
-- \d Dim_SalesTeams
-- \d Dim_Store_location
-- \d FactTable
