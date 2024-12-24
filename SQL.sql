-- Step 1: Create a new database (ignore if already created)
CREATE DATABASE IF NOT EXISTS MarketingCampaign;
USE MarketingCampaign;

-- Step 2: Create a table for the dataset
CREATE TABLE IF NOT EXISTS CampaignData (
    ID INT PRIMARY KEY,
    Year_Birth INT,
    Education VARCHAR(50),
    Marital_Status VARCHAR(50),
    Income FLOAT,
    Kidhome INT,
    Teenhome INT,
    Dt_Customer DATE,
    Recency INT,
    MntWines INT,
    MntFruits INT,
    MntMeatProducts INT,
    MntFishProducts INT,
    MntSweetProducts INT,
    MntGoldProds INT,
    NumDealsPurchases INT,
    NumWebPurchases INT,
    NumCatalogPurchases INT,
    NumStorePurchases INT,
    NumWebVisitsMonth INT,
    AcceptedCmp3 INT,
    AcceptedCmp4 INT,
    AcceptedCmp5 INT,
    AcceptedCmp1 INT,
    AcceptedCmp2 INT,
    Complain INT,
    Z_CostContact INT,
    Z_Revenue INT,
    Response INT
);


-- Step 3: Verify the structure
DESCRIBE CampaignData;


LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/marketing_campaign_cleaned.csv'
INTO TABLE CampaignData
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@ID, @Year_Birth, @Education, @Marital_Status, @Income, @Kidhome, @Teenhome, @Dt_Customer, 
@Recency, @MntWines, @MntFruits, @MntMeatProducts, @MntFishProducts, @MntSweetProducts, 
@MntGoldProds, @NumDealsPurchases, @NumWebPurchases, @NumCatalogPurchases, @NumStorePurchases, 
@NumWebVisitsMonth, @AcceptedCmp3, @AcceptedCmp4, @AcceptedCmp5, @AcceptedCmp1, @AcceptedCmp2, 
@Complain, @Z_CostContact, @Z_Revenue, @Response)
SET 
  Income = NULLIF(TRIM(@Income), ''), -- Convert blank or whitespace values to NULL
  ID = @ID,
  Year_Birth = @Year_Birth,
  Education = @Education,
  Marital_Status = @Marital_Status,
  Kidhome = @Kidhome,
  Teenhome = @Teenhome,
  Dt_Customer = STR_TO_DATE(@Dt_Customer, '%Y-%m-%d'),
  Recency = @Recency,
  MntWines = @MntWines,
  MntFruits = @MntFruits,
  MntMeatProducts = @MntMeatProducts,
  MntFishProducts = @MntFishProducts,
  MntSweetProducts = @MntSweetProducts,
  MntGoldProds = @MntGoldProds,
  NumDealsPurchases = @NumDealsPurchases,
  NumWebPurchases = @NumWebPurchases,
  NumCatalogPurchases = @NumCatalogPurchases,
  NumStorePurchases = @NumStorePurchases,
  NumWebVisitsMonth = @NumWebVisitsMonth,
  AcceptedCmp3 = @AcceptedCmp3,
  AcceptedCmp4 = @AcceptedCmp4,
  AcceptedCmp5 = @AcceptedCmp5,
  AcceptedCmp1 = @AcceptedCmp1,
  AcceptedCmp2 = @AcceptedCmp2,
  Complain = @Complain,
  Z_CostContact = @Z_CostContact,
  Z_Revenue = @Z_Revenue,
  Response = @Response;



SELECT *
FROM CampaignData
LIMIT 50;

COMMIT;


-- Business questions 1. Customer Demographics Analysis
-- Q1.  What is the distribution of customers across different income ranges, and how does it correlate with their education level? 
 
SELECT CASE
         WHEN income < 30000 THEN 'LOW INCOME'
         WHEN income BETWEEN 30000 AND 50000 THEN 'LOWER-MIDDLE INCOME'
         WHEN income BETWEEN 50001 AND 70000 THEN 'UPPER-MIDDLE INCOME'
         ELSE 'HIGH INCOME'
	   END AS IncomeRange,
       education_level AS Education_level,
       COUNT(customer_id) AS Customer_Count
FROM customer
GROUP BY CASE 
           WHEN income < 30000 THEN 'LOW INCOME'
           WHEN income BETWEEN 30000 AND 50000 THEN 'LOWER-MIDDLE INCOME'
           WHEN income BETWEEN 50001 AND 70000 THEN 'UPPER-MIDDLE INCOME'
		   ELSE 'HIGH INCOME'
         END,
         education_level
ORDER BY IncomeRange, Education_level;

-- Business questions 2. Activity Recency
-- Q2.   What is the average recency of activity for customers grouped by marital status?

SELECT status AS marital_status
     , AVG(recency) AS AvgRecency
FROM customer_activity c
 INNER JOIN marital_status m ON c.customer_id = m.customer_id 
GROUP BY marital_status
ORDER BY 2 DESC;

-- Business questions 3. Complaint Trends
-- Q3.  What percentage of customers who complained have higher spending on luxury goods like wines and gold products?
# Average Luxury spending for non-complaint customers 
WITH NonComplainAvg AS (
SELECT AVG(p.MntWines + p.MntGoldProds) AS AvgLuxurySpending 
FROM complain c
 INNER JOIN customer_activity cu ON c.activity_id = cu.activity_id
 INNER JOIN customer cus ON cu.customer_id = cus.customer_id
 INNER JOIN customer_method cm ON cus.customer_id = cm.customer_id
 INNER JOIN product_purchase p ON cm.purchase_method_id = p.purchase_method_id
WHERE c.complain = 0 # Non complaint customers 
),
ComplainLuxurySpending AS (
 SELECT (p.MntWines + p.MntGoldProds) AS TotalLuxurySpending_complains 
 FROM complain c 
  INNER JOIN customer_activity cu ON c.activity_id = cu.activity_id
  INNER JOIN customer cus ON cu.customer_id = cus.customer_id
  INNER JOIN customer_method cm ON cus.customer_id = cm.customer_id
  INNER JOIN product_purchase p ON cm.purchase_method_id = p.purchase_method_id
 WHERE c.complain = 1
)
SELECT CASE
         WHEN TotalLuxurySpending_complains  > (SELECT AvgLuxurySpending FROM NonComplainAvg) THEN 'Higher_spending'
         ELSE 'Lower_spending'
	   END AS HigherSpendingCustomer_in_complain
     , COUNT(*) AS Customer_Count 
     , CONCAT(ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 2), '%') AS Percentage
FROM ComplainLuxurySpending
GROUP BY HigherSpendingCustomer_in_complain;

-- Business questions 4. Campaign Response by Family Size
-- Q4.   Does family size affect the likelihood of responding to campaigns? If so, which campaigns are most successful? 
WITH KidsAndTeens AS (
SELECT marital_status_id
     , CASE
         WHEN kid_home > 0 OR teen_home > 0 THEN 1 
         ELSE 0
		END AS HaskidsOrTeens
FROM customer_kids
),
MaritalStatus AS (
SELECT marital_status_id  
     , customer_id
     , CASE
         WHEN Status = 'Married' THEN 2
         WHEN Status = 'Single' THEN 1
         WHEN Status = 'Together' THEN 2
         WHEN Status = 'Divorced' THEN 1
         ELSE 1
	   END AS MaritalStatusScore
FROM marital_status
),
FamilySize AS (
SELECT k.marital_status_id
     , m.customer_id
     , k.HaskidsOrTeens
     , m.MaritalStatusScore
     , (k.HaskidsOrTeens + m.MaritalStatusScore) AS FamilySize
FROM KidsAndTeens k
 INNER JOIN MaritalStatus m ON k.marital_status_id = m.marital_status_id
),
CampaignResponseFamilySize AS (
SELECT c.customer_id
     , f.marital_status_id
     , f.HasKidsOrTeens
     , f.FamilySize
     , (AcceptedCmp1 + AcceptedCmp2 + AcceptedCmp3 + AcceptedCmp4 + AcceptedCmp5 + Response) AS TotalResponses
FROM campaign_response c
 INNER JOIN FamilySize f ON c.customer_id = f.customer_id
)
SELECT FamilySize
     , AVG(TotalResponses) AS AvgResponses
FROM CampaignResponseFamilySize
GROUP BY FamilySize
ORDER BY FamilySize DESC;

-- Business questions 5. Campaign Response Rate
-- Q5. which campaigns are most successful? 

WITH CampaignResponses AS (
SELECT SUM(AcceptedCmp1) AS TotalAcceptedCmp1
     , SUM(AcceptedCmp2) AS TotalAcceptedCmp2
     , SUM(AcceptedCmp3) AS TotalAcceptedCmp3
     , SUM(AcceptedCmp4) AS TotalAcceptedCmp4
     , SUM(AcceptedCmp5) AS TotalAcceptedCmp5
     , SUM(Response) AS TotalAcceptedLastCampaign
	 , COUNT(customer_id) AS TotalCustomers 
FROM campaign_response
) 
SELECT 'Campaign1' AS Campaign
      , TotalAcceptedCmp1 / TotalCustomers  AS ResponseRate
FROM CampaignResponses
UNION ALL
SELECT 'Campaign2' AS Campaign
     , TotalAcceptedCmp2 / TotalCustomers AS ResponseRate
FROM CampaignResponses
UNION ALL
SELECT 'Campaign3' AS Campaign
     , TotalAcceptedCmp3 / TotalCustomers AS ResponseRate
FROM CampaignResponses
UNION ALL
SELECT 'Campaign4' AS Campaign
     , TotalAcceptedCmp4 / TotalCustomers AS ResponseRate
FROM CampaignResponses
UNION ALL
SELECT 'Campaign5' AS Campaign
     , TotalAcceptedCmp5 / TotalCustomers AS ResponseRate
FROM CampaignResponses
UNION ALL
SELECT 'CampaignLast' AS Campaign
     , TotalAcceptedLastCampaign / TotalCustomers AS ResponseRate
FROM CampaignResponses
ORDER BY ResponseRate DESC;

-- Business questions 6.  Customer Lifetime Value (CLTV) Indicators
-- Q5.  What is the average spending for customers segmented by their first campaign acceptance?

SELECT customer_id
     , AcceptedCmp1
FROM campaign_response;

WITH TotalSpending AS (
SELECT p.purchase_method_id
     , c.customer_id
     , (p.MntFishProducts + p.MntFruits + p.MntGoldProds + p.MntMeatProducts + p.MntWines) AS TotalSpending
FROM product_purchase p
 INNER JOIN customer_method c ON p.purchase_method_id = c.purchase_method_id
),
CampaignAccepted AS (
SELECT customer_id
     , CASE 
          WHEN AcceptedCmp1 = 1 THEN 'Campaign 1'
          WHEN AcceptedCmp2 = 1 THEN 'Campaign 2'
          WHEN AcceptedCmp3 = 1 THEN 'Campaign 3'
          WHEN AcceptedCmp4 = 1 THEN 'Campaign 4'
          WHEN AcceptedCmp5 = 1 THEN 'Campaign 5'
          ELSE 'Last Campaign Accepted'
		END AS CampaignAcceptedResponse
FROM campaign_response
)
SELECT ca.CampaignAcceptedResponse
     , FORMAT(SUM(t.TotalSpending), 2) AS TotalSpendingbyResponse
FROM TotalSpending t
 INNER JOIN CampaignAccepted ca ON t.customer_id = ca.customer_id
GROUP BY ca.CampaignAcceptedResponse
ORDER BY 2 DESC;


-- Business questions 7.  New Customers 
-- Q7.   Which month had the highest number of new customer registrations?
WITH MonthData AS (
SELECT customer_id
     , MONTH(dt_customer) AS Month
FROM customer_activity
)
SELECT m.Month
     , COUNT(c.customer_id) AS CustomerRegistration
     , FORMAT(SUM(c.income),2) AS TotalIncome
FROM customer c
 INNER JOIN MonthData m ON c.customer_id = m.customer_id
GROUP BY m.Month
ORDER BY 2 DESC
LIMIT 1;

-- Business questions 10. Spending Consistency
-- Q8.   How consistent is the spending behavior of customers across different product categories over the last two years? 

WITH CustomerSpendingdata AS (
SELECT c.customer_id
     , SUM(p.MntWines) AS TotalWines 
     , SUM(p.MntFishProducts) AS TotalFish
     , SUM(p.MntFruits) AS TotalFruits
     , SUM(p.MntGoldProds) AS TotalGold
     , SUM(p.MntMeatProducts) AS TotalMeat
     , SUM(p.MntSweetProducts) AS TotalSweet 
FROM product_purchase p
 INNER JOIN customer_method c ON p.purchase_method_id = c.purchase_method_id
GROUP BY c.customer_id
),
CustomerMeanSTDdata AS (
SELECT customer_id 
     , (TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6 AS AverageSpending
     , SQRT(
            POWER(TotalWines - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) +
            POWER(TotalFish - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) + 
            POWER(TotalFruits - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) +
            POWER(TotalGold - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) +
            POWER(TotalMeat - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) +
            POWER(TotalSweet - ((TotalWines + TotalFish + TotalFruits + TotalGold + TotalMeat + TotalSweet) / 6), 2) 
            ) / 6 AS STDSpending
FROM CustomerSpendingdata
)
SELECT customer_id
     , AverageSpending
     , STDSpending
     , CASE
         WHEN AverageSpending = 0 THEN NULL
         ELSE STDSpending / AverageSpending 
       END AS COV # Coefficient of Variation   
FROM CustomerMeanSTDdata ;
