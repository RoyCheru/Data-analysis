--1. CUSTOMER MANAGEMENT
	--Retrieving All Customer Information

select * from customers
	--Find Customers with Missing Addresses or Email Addresses
SELECT * FROM customers WHERE address IS NULL OR email IS NULL;
	--Counting the Number of Unique Customers
SELECT COUNT(DISTINCT customer_id) AS total_customers FROM customers;

--2.ACCOUNT MANAGEMENT
	--All Accounts with Their Associated Customers:
SELECT a.account_id, a.account_type, a.balance, a.account_status, c.first_name, c.last_name
FROM accounts a
JOIN customers c ON a.customer_id = c.customer_id;
	--Finding Inactive Accounts or Accounts with Zero Balance:
SELECT * FROM accounts WHERE account_status = 'Inactive' OR balance = 0;
	--Calculating the Total Balance Across All Accounts
SELECT SUM(balance) AS total_balance FROM accounts;
	--Grouping Accounts by Type and Calculating the Average Balance for Each Type:
SELECT account_type, AVG(balance) AS average_balance
FROM accounts
GROUP BY account_type;

--3. TRANSACTION TRACKING 
	--Retrieving All Transactions for a Specific Account
SELECT * FROM transactions WHERE account_id = 1;
	--Finding Transactions with Missing Dates or Negative Amounts
SELECT * FROM transactions WHERE transaction_date IS NULL OR amount < 0;
	--Calculate the Total Number of Transactions per Account
SELECT account_id, COUNT(*) AS total_transactions
FROM transactions
GROUP BY account_id;
	--Sum of All Deposits Made in a Given Month
SELECT SUM(amount) AS total_deposits
FROM transactions
WHERE transaction_type = 'Deposit' AND transaction_date BETWEEN '2024-01-01' AND '2024-01-31';
	--Finding the Top 5 Largest Withdrawals
SELECT * FROM transactions
WHERE transaction_type = 'Withdrawal'
ORDER BY amount DESC
LIMIT 5;



--4. BRANCH MANAGEMENT 
	--Listing All Branches and the Number of Accounts Associated with Each Branch
select branch_name,c.no_of_accounts from branches b
JOIN (select branch_id, count(account_id) as no_of_accounts from accounts
group by branch_id order by branch_id)c
ON c.branch_id = b.branch_id

	--alternatively:
SELECT b.branch_name, COUNT(a.account_id) AS total_accounts
FROM branches b
LEFT JOIN accounts a ON b.branch_id = a.branch_id
GROUP BY b.branch_name;
	--Retrieve Transactions Grouped by Branch Location

select transaction_type, a.account_id,b.branch_location from accounts a
JOIN transactions t ON t.account_id = a.account_id
JOIN branches b on b.branch_id = a.branch_id
GROUP BY b.branch_location,transaction_type, a.account_id
	--alternatively
SELECT b.branch_location, COUNT(t.transaction_id) AS total_transactions
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN branches b ON a.branch_id = b.branch_id
GROUP BY b.branch_location;

--5.DATA CLEANING
	--Updating Missing Account Status to 'Active'
UPDATE accounts
SET account_status = 'Active'
WHERE account_status IS NULL;
	--Fill in Missing Transaction Dates with a Default Date (e.g., Current Date)
UPDATE transactions
SET transaction_date = CURRENT_DATE
WHERE transaction_date IS NULL;
	--Removing Duplicate Customer Records (assuming duplicates are identified by matching first and last names):
DELETE FROM customers
WHERE customer_id NOT IN (
    SELECT MIN(customer_id)
    FROM customers
    GROUP BY first_name, last_name
);

--6.ADVANCED ANALYSIS AND REPORTING
SELECT * FROM ACCOUNTS
select * from transactions

select c.customer_id,a.account_id,sum(amount) as total_deposits from customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
WHERE transaction_type = 'Deposit'
GROUP BY c.customer_id,a.account_id  

select c.customer_id,a.account_id,sum(amount) as total_withdrawals from customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
WHERE transaction_type = 'Withdrawal'
GROUP BY c.customer_id,a.account_id  

SELECT COALESCE(b.customer_id,c.customer_id),b.total_deposits,c.total_withdrawals
FROM (select c.customer_id,a.account_id,sum(amount) as total_deposits from customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
WHERE transaction_type = 'Deposit'
GROUP BY c.customer_id,a.account_id )b
FULL OUTER JOIN (select c.customer_id,a.account_id,sum(amount) as total_withdrawals from customers c
JOIN accounts a ON a.customer_id = c.customer_id
JOIN transactions t ON t.account_id = a.account_id
WHERE transaction_type = 'Withdrawal'
GROUP BY c.customer_id,a.account_id  )c ON b.customer_id = c.customer_id
	--alternatively(using the case clause)
SELECT c.customer_id, c.first_name, c.last_name,
       SUM(CASE WHEN t.transaction_type = 'Deposit' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type = 'Withdrawal' THEN t.amount ELSE 0 END) AS total_withdrawals
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
JOIN transactions t ON a.account_id = t.account_id
GROUP BY c.customer_id, c.first_name, c.last_name;

	--The most Active Branch Based on the Number of Transactions
select count(transaction_id) as total_transactions,branch_name from branches b
JOIN accounts a ON a.branch_id = b.branch_id
JOIN transactions t ON t.account_id = a.account_id
GROUP BY branch_name limit 1;
	--alternatively
SELECT b.branch_name, COUNT(t.transaction_id) AS total_transactions
FROM branches b
JOIN accounts a ON b.branch_id = a.branch_id
JOIN transactions t ON a.account_id = t.account_id
GROUP BY b.branch_name
ORDER BY total_transactions DESC
LIMIT 1;
	--Identify Accounts with Frequent Large Withdrawals (e.g., More Than 3 Withdrawals Exceeding $500):
SELECT account_id,count(transaction_id) as no_of_withdrawals from transactions
WHERE transaction_type = 'Withdrawal' AND amount>500 
GROUP BY account_id
having count(transaction_id) > 1
	--alternatively
SELECT a.account_id, COUNT(*) AS large_withdrawals
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
WHERE t.transaction_type = 'Withdrawal' AND t.amount > 500
GROUP BY a.account_id
HAVING COUNT(*) > 3;

--refreshing
