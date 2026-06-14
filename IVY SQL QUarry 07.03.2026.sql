CREATE DATABASE investment_analytics;
USE investment_analytics;

CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    client_name VARCHAR(100),
    gender VARCHAR(10),
    city VARCHAR(50),
    risk_profile VARCHAR(20),
    onboarding_date DATE
);

CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    client_id INT,
    account_type VARCHAR(30),
    status VARCHAR(20),
    opened_date DATE,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

CREATE TABLE transactions (
    transaction_id INT PRIMARY KEY,
    account_id INT,
    transaction_date DATE,
    transaction_type VARCHAR(10),
    amount DECIMAL(12,2),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

Select * From clients;
Select * From accounts;

/* AUM (Assets Under Management) =
Total net investment value managed by firm.*/ 

/*
Business Question:
What is the total Assets Under Management (AUM)?

Approach:
Use conditional aggregation to treat Sell transactions as negative.
*/

SELECT 
    SUM(CASE 
            WHEN transaction_type = 'Buy' THEN amount
            WHEN transaction_type = 'Sell' THEN -amount
        END) AS total_aum
FROM transactions;

/*
Business Question:
What is the net investment (AUM) per client?

Approach:
Join clients → accounts → transactions
Use conditional aggregation to calculate net investment.
*/

SELECT 
    c.client_id,
    c.client_name,
    SUM(CASE 
            WHEN t.transaction_type = 'Buy' THEN t.amount
            WHEN t.transaction_type = 'Sell' THEN -t.amount
        END) AS client_aum
FROM clients c
JOIN accounts a 
    ON c.client_id = a.client_id
JOIN transactions t 
    ON a.account_id = t.account_id
GROUP BY c.client_id, c.client_name
ORDER BY client_aum DESC
limit 10;

SELECT 
    transaction_type,
    SUM(amount) AS total_amount
FROM transactions
GROUP BY transaction_type;

-- =====================================================
-- SECTION 3: Time-Based Portfolio Analysis
-- =====================================================

/*
Business Context:
Understanding monthly transaction trends helps identify 
investment behavior patterns and portfolio inflow/outflow dynamics.

Business Question:
How do Buy and Sell transaction volumes vary month-over-month?

Analytical Approach:
- Extract Year and Month from transaction_date
- Aggregate Buy and Sell separately using conditional aggregation
- Order results chronologically for trend analysis
*/

-- =====================================================
-- Monthly Buy vs Sell Trend Analysis
-- =====================================================

/*
Business Question:
How do Buy and Sell transaction volumes vary month-over-month?
*/

SELECT 
    DATE_FORMAT(transaction_date, '%b-%Y') AS month,
    SUM(CASE WHEN transaction_type = 'Buy' THEN amount ELSE 0 END) AS total_buy,
    SUM(CASE WHEN transaction_type = 'Sell' THEN amount ELSE 0 END) AS total_sell
FROM transactions
GROUP BY DATE_FORMAT(transaction_date, '%b-%Y'),
         YEAR(transaction_date),
         MONTH(transaction_date)
ORDER BY YEAR(transaction_date),
         MONTH(transaction_date);
         
/*
Business Question:
How do Buy and Sell volumes trend over time (excluding incomplete months)?

Purpose:
Exclude partial last month to avoid distorted trend interpretation.
*/

SELECT 
    DATE_FORMAT(transaction_date, '%b-%Y') AS month,
    SUM(CASE WHEN transaction_type = 'Buy' THEN amount ELSE 0 END) AS total_buy,
    SUM(CASE WHEN transaction_type = 'Sell' THEN amount ELSE 0 END) AS total_sell
FROM transactions
WHERE transaction_date < '2023-01-01'   -- adjust based on your dataset
GROUP BY 
    YEAR(transaction_date),
    MONTH(transaction_date),
    DATE_FORMAT(transaction_date, '%b-%Y')
ORDER BY 
    YEAR(transaction_date),
    MONTH(transaction_date);


SELECT 
    DATE_FORMAT(transaction_date,'%b-%Y') AS month,
    COUNT(*) AS total_transactions
FROM transactions
GROUP BY 
    YEAR(transaction_date),
    MONTH(transaction_date),
    DATE_FORMAT(transaction_date,'%b-%Y')
ORDER BY 
    YEAR(transaction_date),
    MONTH(transaction_date);


/*
Business Question:
What is the Buy vs Sell ratio and net difference?
*/

SELECT 
    SUM(CASE WHEN transaction_type = 'Buy' THEN amount END) AS total_buy,
    SUM(CASE WHEN transaction_type = 'Sell' THEN amount END) AS total_sell,
    SUM(CASE WHEN transaction_type = 'Buy' THEN amount
             WHEN transaction_type = 'Sell' THEN -amount END) AS net_difference,
    ROUND(
        SUM(CASE WHEN transaction_type = 'Buy' THEN amount END) /
        SUM(CASE WHEN transaction_type = 'Sell' THEN amount END),
    2) AS buy_sell_ratio
FROM transactions;


-- =====================================================
-- BUSINESS QUESTION:
-- Which clients contribute the most to the firm's portfolio value?
-- =====================================================

-- BUSINESS PURPOSE:
-- Identifying top investors helps financial firms prioritize
-- relationship management and high-value client engagement.

-- ANALYTICAL APPROACH:
-- 1. Join Clients → Accounts → Transactions
-- 2. Convert Sell transactions into negative values
-- 3. Calculate Net Investment (AUM) per client
-- 4. Rank clients using a Window Function

SELECT 
    c.client_id,                      -- Unique client identifier
    c.client_name,                    -- Client name
    
    -- Calculate Net Investment (AUM) per client
    SUM(
        CASE 
            WHEN t.transaction_type = 'Buy' THEN t.amount
            WHEN t.transaction_type = 'Sell' THEN -t.amount
        END
    ) AS client_aum,

    -- Rank clients based on their portfolio value
    RANK() OVER (
        ORDER BY 
            SUM(
                CASE 
                    WHEN t.transaction_type = 'Buy' THEN t.amount
                    WHEN t.transaction_type = 'Sell' THEN -t.amount
                END
            ) DESC
    ) AS client_rank

FROM clients c

-- Join accounts to link clients with their investment accounts
JOIN accounts a 
    ON c.client_id = a.client_id

-- Join transactions to analyze investment activity
JOIN transactions t 
    ON a.account_id = t.account_id

-- Group data at the client level
GROUP BY 
    c.client_id, 
    c.client_name

-- Order by rank to identify top investors
ORDER BY client_rank

-- Limit output to top 10 clients
LIMIT 10;

-- =====================================================
-- BUSINESS QUESTION:
-- How has the firm's cumulative AUM changed month-over-month?
-- =====================================================

-- BUSINESS PURPOSE:
-- Monitoring AUM growth helps investment firms understand
-- portfolio expansion, investment inflows, and withdrawal trends.

-- ANALYTICAL APPROACH:
-- 1. Convert Buy transactions to positive values
-- 2. Convert Sell transactions to negative values
-- 3. Aggregate transactions at monthly level
-- 4. Use a window function to calculate cumulative AUM

WITH monthly_net_investment AS (

SELECT
    DATE_FORMAT(transaction_date,'%Y-%m') AS month,

    SUM(
        CASE
            WHEN transaction_type = 'Buy' THEN amount
            WHEN transaction_type = 'Sell' THEN -amount
        END
    ) AS monthly_net

FROM transactions
GROUP BY DATE_FORMAT(transaction_date,'%Y-%m')

)

SELECT
    month,
    monthly_net,

    -- Running cumulative AUM
    SUM(monthly_net) OVER (
        ORDER BY month
    ) AS cumulative_aum

FROM monthly_net_investment
ORDER BY month;

-- Monthly Net Investment Trend

SELECT
    DATE_FORMAT(transaction_date,'%Y-%m') AS month,

    SUM(
        CASE
            WHEN transaction_type = 'Buy' THEN amount
            WHEN transaction_type = 'Sell' THEN -amount
        END
    ) AS monthly_net_investment

FROM transactions

GROUP BY DATE_FORMAT(transaction_date,'%Y-%m')

ORDER BY month
limit 12;

-- =====================================================
-- BUSINESS QUESTION:
-- Which clients generate the highest trading activity?
-- =====================================================

-- BUSINESS PURPOSE:
-- Identifying highly active investors helps financial
-- firms understand trading behavior and client engagement.

-- ANALYTICAL APPROACH:
-- 1. Join Clients → Accounts → Transactions tables
-- 2. Count total transactions executed by each client
-- 3. Rank clients by trading activity
-- 4. Identify the top 10 most active investors

SELECT 
    c.client_id,                 -- Unique client identifier
    c.client_name,               -- Client name
    
    -- Count total transactions executed by the client
    COUNT(t.transaction_id) AS total_transactions

FROM clients c

-- Join accounts to connect clients with their investment accounts
JOIN accounts a 
    ON c.client_id = a.client_id

-- Join transactions to analyze trading activity
JOIN transactions t 
    ON a.account_id = t.account_id

-- Aggregate results at the client level
GROUP BY 
    c.client_id, 
    c.client_name

-- Sort clients by highest transaction activity
ORDER BY total_transactions DESC

-- Limit output to the top 10 most active investors
LIMIT 10;

-- ======================================================
-- BUSINESS QUESTION:
-- How is the portfolio value distributed across different client risk profiles?
-- ======================================================

-- BUSINESS PURPOSE:
-- Understanding investment allocation across Low, Medium, and High risk segments
-- helps financial firms assess portfolio diversification and risk exposure.

SELECT 
    c.risk_profile,
    SUM(t.amount) AS total_investment
FROM clients c
JOIN accounts a 
    ON c.client_id = a.client_id
JOIN transactions t 
    ON a.account_id = t.account_id
WHERE t.transaction_type = 'Buy'
GROUP BY c.risk_profile
ORDER BY total_investment DESC;

-- ======================================================
-- BUSINESS QUESTION:
-- Which cities generate the highest portfolio investment value?
-- ======================================================

-- BUSINESS PURPOSE:
-- Understanding geographic investment concentration helps financial
-- firms identify key markets where investor participation is strongest
-- and where client acquisition strategies may be most effective.

-- ANALYTICAL APPROACH:
-- 1. Join Clients → Accounts → Transactions tables
-- 2. Convert Buy transactions to positive values
-- 3. Convert Sell transactions to negative values
-- 4. Calculate Net Investment (AUM) per city
-- 5. Rank cities by highest investment contribution

SELECT 
    c.city,

    SUM(
        CASE
            WHEN t.transaction_type = 'Buy'  THEN t.amount
            WHEN t.transaction_type = 'Sell' THEN -t.amount
        END
    ) AS city_aum

FROM clients c

JOIN accounts a
    ON c.client_id = a.client_id

JOIN transactions t
    ON a.account_id = t.account_id

GROUP BY 
    c.city

ORDER BY 
    city_aum DESC

LIMIT 10;


SELECT 
    c.city,
    SUM(t.amount) AS total_investment
FROM clients c
JOIN accounts a
    ON c.client_id = a.client_id
JOIN transactions t
    ON a.account_id = t.account_id
WHERE t.transaction_type = 'Buy'
GROUP BY 
    c.city
ORDER BY 
    total_investment DESC;


