IF OBJECT_ID('dbo.Products','U') IS NULL
CREATE TABLE dbo.Products(id varchar(60) PRIMARY KEY,name nvarchar(120) NOT NULL,priceCents int NOT NULL CHECK(priceCents>=0),category nvarchar(60) NOT NULL,glyph nvarchar(8) NOT NULL);
IF OBJECT_ID('dbo.Orders','U') IS NULL
CREATE TABLE dbo.Orders(id uniqueidentifier PRIMARY KEY,idempotencyKey varchar(80) NOT NULL UNIQUE,payload nvarchar(max) NOT NULL CHECK(ISJSON(payload)=1),createdAt datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
