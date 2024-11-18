CREATE TABLE accounts (
    account_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    account_type VARCHAR(20) CHECK (account_type IN ('Savings', 'Checking', 'Credit')),
    balance NUMERIC(15, 2) DEFAULT 0.00,
    account_status VARCHAR(10) CHECK (account_status IN ('Active', 'Inactive')),
    created_at DATE DEFAULT GETDATE()
);


CREATE TABLE customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,  -- Auto-incrementing column
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE,                 -- Unique constraint on email
    phone_number VARCHAR(15),
    address NVARCHAR(MAX),                     -- Use NVARCHAR(MAX) for text fields
    join_date DATE DEFAULT GETDATE()           -- Default to current date
);

CREATE TABLE transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    account_id INT REFERENCES accounts(account_id),
    transaction_date DATE DEFAULT GETDATE(),
    amount NUMERIC(15, 2),
    transaction_type VARCHAR(10) CHECK (transaction_type IN ('Deposit', 'Withdrawal', 'Transfer')),
    description NVARCHAR(MAX)
);

ALTER TABLE transactions
DROP CONSTRAINT CK__transacti__trans__5629CD9C
ALTER TABLE transactions
ADD CONSTRAINT CK__transacti__trans__5629CD9C
CHECK (transaction_type IN ('Deposit', 'Withdrawal', 'Transfer', 'Purchase'));


CREATE TABLE branches (
    branch_id INT IDENTITY(1,1) PRIMARY KEY,
    branch_name VARCHAR(100) NOT NULL,
    branch_location VARCHAR(200) NOT NULL,
    branch_manager VARCHAR(100),
    contact_number VARCHAR(20)
);

ALTER TABLE accounts
ADD branch_id INT REFERENCES branches(branch_id);

UPDATE accounts
SET branch_id = FLOOR(RAND(CHECKSUM(NEWID())) * 5 + 1)
WHERE account_id BETWEEN 83 AND 122;


--1. CUSTOMER MANAGEMENT
	--Retrieving All Customer Information
	select * from customers
  
	--Finding Customers with Missing Addresses or Email Addresses:
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
	SELECT TOP 5 * 
	FROM transactions
	WHERE transaction_type = 'Withdrawal'
	ORDER BY amount DESC;

--4. BRANCH MANAGEMENT 
	--Listing All Branches and the Number of Accounts Associated with Each Branch
	SELECT branch_name,COUNT(account_id) from branches b
	JOIN accounts a on a.branch_id = b.branch_id
	GROUP BY branch_name

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

---6.ADVANCED ANALYSIS AND REPORTING
	--Calculate the Total Deposits and Withdrawals for Each Customer
	SELECT c.customer_id, c.first_name, c.last_name,
       SUM(CASE WHEN t.transaction_type = 'Deposit' THEN t.amount ELSE 0 END) AS total_deposits,
       SUM(CASE WHEN t.transaction_type = 'Withdrawal' THEN t.amount ELSE 0 END) AS total_withdrawals
	FROM customers c
	JOIN accounts a ON c.customer_id = a.customer_id
	JOIN transactions t ON a.account_id = t.account_id
	GROUP BY c.customer_id, c.first_name, c.last_name;
	--Find the Most Active Branch Based on the Number of Transactions:
	SELECT TOP 1 b.branch_name, COUNT(t.transaction_id) AS total_transactions
	FROM branches b
	JOIN accounts a ON b.branch_id = a.branch_id
	JOIN transactions t ON a.account_id = t.account_id
	GROUP BY b.branch_name
	ORDER BY total_transactions DESC;
	-- Accounts with Frequent Large Withdrawals (e.g., More Than 3 Withdrawals Exceeding $500):
	SELECT a.account_id, COUNT(*) AS large_withdrawals
	FROM transactions t
	JOIN accounts a ON t.account_id = a.account_id
	WHERE t.transaction_type = 'Withdrawal' AND t.amount > 500
	GROUP BY a.account_id
	HAVING COUNT(*) > 3;

--7.TRANSACTION TRACKING
	--We will first setup Audit Triggers for Tracking Modifications
		--setting up transaction_audit table
		CREATE TABLE transaction_audit (
		audit_id INT IDENTITY(1,1) PRIMARY KEY,
		transaction_id INT NOT NULL,
		account_id INT NOT NULL,
		transaction_type VARCHAR(20),
		amount DECIMAL(10, 2),
		transaction_date DATETIME, 
		branch_id INT,
		notes VARCHAR(255),
		modified_by VARCHAR(50),
		modified_at DATETIME DEFAULT GETDATE() 
	);

	--Trigger for Logging Changes
		--The trigger will save a record in the transaction_audit table every time a transaction is updated:
	CREATE TRIGGER after_transaction_update
	ON transactions
	AFTER UPDATE
	AS
	BEGIN
		-- Insert the old transaction data into the transaction_audit table
    INSERT INTO transaction_audit (
        transaction_id,
        account_id,
        transaction_type,
        amount,
        transaction_date,
        modified_by,
        modified_at
    )
    SELECT 
        d.transaction_id,    -- DELETED table for OLD values
        d.account_id,
        d.transaction_type,
        d.amount,
        d.transaction_date,
        SYSTEM_USER,          -- Automatically captures the current user modifying the data
        CURRENT_TIMESTAMP     -- Capture the current timestamp
    FROM DELETED d;        -- DELETED table holds the old row values before update

END;
	--testing the trigger by doing a transaction
		UPDATE transactions
		SET amount = 500
		WHERE transaction_id = 13;

-- STORED PROCEDURES.
	--stored procedure to add a transaction, including the amount, type, date, and account ID
	CREATE PROCEDURE dbo.AddTransaction
    @account_id INT,
    @Amount DECIMAL(10, 2),
    @transaction_type NVARCHAR(10),
    @transaction_date DATE
AS
BEGIN
    -- Insert a new transaction record into the Transactions table
    BEGIN TRY
        INSERT INTO Transactions (account_id, Amount, transaction_type, transaction_date)
        VALUES (@account_id, @Amount, @transaction_type, @transaction_date);
    END TRY
    BEGIN CATCH
        -- Error handling: capture the error message
        PRINT 'Error occurred: ' + ERROR_MESSAGE();
        -- Optionally, you can raise the error again
        THROW;
    END CATCH
END;

		--adding a transaction using the stored procedure
		EXEC dbo.AddTransaction @account_id = 99, @Amount = 500, @transaction_type = 'Purchase', @transaction_date = '2024-11-01';

	--A stored procedure to retrieve the current balance of an account,which could include both Credit and Debit transactions.
		CREATE PROCEDURE dbo.GetAccountBalance
    @account_id INT
	AS
	BEGIN
		SELECT @account_id AS AccountID,
			   SUM(CASE WHEN transaction_type = 'Credit' THEN Amount ELSE -Amount END) AS Balance
		FROM Transactions
		WHERE account_id = @account_id;
	END;
		--usage
		EXEC dbo.GetAccountBalance @account_id = 90;

	-- Generating  Monthly Statement
		--This procedure generates a statement for a specific account and month, showing transactions and a running balance
			CREATE PROCEDURE dbo.GenerateMonthlyStatement
		@AccountID INT,
		@Year INT,
		@Month INT
		AS
		BEGIN
			SELECT 
				transaction_id,
				transaction_date,
				transaction_type,
				Amount,
				SUM(CASE WHEN transaction_type = 'Credit' THEN Amount ELSE -Amount END) 
					OVER (ORDER BY transaction_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningBalance
			FROM Transactions
			WHERE account_id = @AccountID 
			AND YEAR(transaction_date) = @Year 
			AND MONTH(transaction_date) = @Month
			ORDER BY transaction_date;
		END;
			--usage
			EXEC dbo.GenerateMonthlyStatement @AccountID = 86, @Year = 2024, @Month = 10;

	--Updating Account Overdraft Limit
	ALTER table accounts
	ADD OverdraftLimit INT
		
		CREATE PROCEDURE dbo.UpdateOverdraftLimit
    @AccountID INT,
    @NewLimit DECIMAL(10, 2)
	AS
	BEGIN
		UPDATE Accounts
		SET OverdraftLimit = @NewLimit
		WHERE account_id = @AccountID;
	END;
		--usage
		EXEC dbo.UpdateOverdraftLimit @AccountID = 94, @NewLimit = 1000.00;

		--A STORED PROCEDURE TO PREVENT NEGATIVE BALANCE
			--this will validate account balance before inserting any transaction
			CREATE PROCEDURE NewTransaction
		@AccountID INT,
		@TransactionType NVARCHAR(10),
		@Amount DECIMAL(10, 2),
		@Description NVARCHAR(MAX) = NULL
	AS
	BEGIN
		SET NOCOUNT ON;

		DECLARE @CurrentBalance DECIMAL(10, 2);

		-- Get current balance
		SELECT @CurrentBalance = Balance
		FROM Accounts
		WHERE account_id = @AccountID;

		-- Check for negative balance on withdrawals
		IF @TransactionType = 'Withdrawal' AND @CurrentBalance - @Amount < 0
		BEGIN
			RAISERROR ('Transaction would result in a negative balance.', 16, 1);
			RETURN;
		END;

		-- Insert the transaction
		INSERT INTO Transactions (account_id, transaction_date, Amount, transaction_type, description)
		VALUES (@AccountID, GETDATE(), @Amount, @TransactionType, @Description);

		-- Update the balance in the Accounts table
		UPDATE Accounts
		SET Balance = Balance + CASE 
			WHEN @TransactionType = 'Deposit' THEN @Amount
			ELSE -@Amount
		END
		WHERE account_id = @AccountID;
	END;


--MORE TRIGGERS FOR OUR DATABASE
	--A trigger to Prevent Negative Account Balance


	CREATE TRIGGER trg_PreventNegativeBalance
	ON Transactions
	INSTEAD OF INSERT
	AS
	BEGIN
		SET NOCOUNT ON;

		-- Validate balance for each inserted row
		DECLARE @AccountID INT, @TransactionType VARCHAR(10), @Amount DECIMAL(10, 2);

		SELECT 
			@AccountID = i.account_id, 
			@TransactionType = i.transaction_type, 
			@Amount = i.Amount
		FROM inserted i;

		IF @TransactionType IN ('Withdrawal', 'Purchase', 'Transfer')
		BEGIN
			DECLARE @CurrentBalance DECIMAL(10, 2);

			-- Get the current balance from Accounts table
			SELECT @CurrentBalance = Balance
			FROM Accounts
			WHERE account_id = @AccountID;

			-- Check if withdrawal exceeds balance
			IF @CurrentBalance - @Amount < 0
			BEGIN
				RAISERROR ('Transaction would result in a negative balance.', 16, 1);
				ROLLBACK TRANSACTION;
				RETURN;
			END;
		END;

		-- If validation passes, insert the transaction
		INSERT INTO Transactions (account_id, transaction_date, Amount, transaction_type, Description)
		SELECT account_id, transaction_date, Amount, transaction_type, Description
		FROM inserted;

		-- Update the balance in the Accounts table
		UPDATE Accounts
		SET Balance = CASE 
						 WHEN @TransactionType IN ('Withdrawal', 'Purchase', 'Transfer') THEN Balance - @Amount
						 WHEN @TransactionType = 'Deposit' THEN Balance + @Amount
						 ELSE Balance
					  END
		WHERE account_id = @AccountID;
	END;


	--testing the trigger
		-- we will use a stored procedure to create a transaction 
	EXEC dbo.AddTransaction @account_id = 87, @Amount = 2000, @transaction_type = 'Purchase', @transaction_date = '2024-11-17';
	EXEC dbo.AddTransaction @account_id = 88, @Amount = 2000, @transaction_type = 'Deposit', @transaction_date = '2024-11-17'


--BACKUP AND RECOVERY
	--FULL BACKUP
	BACKUP DATABASE FinancialTransactions
TO DISK = 'C:\Backups\FinancialTransactions.bak'
WITH FORMAT, INIT, NAME = 'Full Backup of FinancialTransactions';
	--Setting Up Incremental Backups
	BACKUP LOG FinancialTransactions
TO DISK = 'C:\Backups\FinancialTransactions_Log.bak'
WITH INIT, NAME = 'Transaction Log Backup';

	--Automating database backups using a script and SQL Server Agent:
	-- Full Backup Script
BACKUP DATABASE FinancialTransactions
TO DISK = 'C:\Backups\FinancialTransactions.bak'
WITH FORMAT, INIT, NAME = 'Full Backup';





