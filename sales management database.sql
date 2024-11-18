-- Retrieving all products  in their respective categories and ordered based on stock quantity
select product_name,category,stock_quantity from products
ORDER BY category,stock_quantity desc

--detailed history of orders for each customer:
SELECT u.user_id, u.username, o.order_id, o.order_date, SUM(oi.quantity * oi.price) AS order_total
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY u.user_id, o.order_id
ORDER BY u.user_id, o.order_date DESC;

	
--all orders placed by a particular customer
	--We will create a function
	CREATE OR REPLACE FUNCTION get_orders_by_customer(p_customer_id INT)
RETURNS TABLE(
    order_id INT,
    order_date DATE,
    product_name TEXT,
    quantity INT,
    total_amount NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.order_id,
        o.order_date,
        p.name AS product_name,
        od.quantity,
        od.quantity * p.price AS total_amount
    FROM 
        orders o
    JOIN 
        order_items oi ON o.order_id = oi.order_id
    JOIN 
        products p ON oi.product_id = p.product_id
    WHERE 
        o.customer_id = p_customer_id;
END;
$$ LANGUAGE plpgsql;


-- the Most Frequently Ordered Products
SELECT p.product_id, p.product_name, COUNT(oi.order_item_id) AS order_count
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name
ORDER BY order_count DESC;


--products with stock quantities below a certain threshold.
SELECT product_id, product_name, stock_quantity
FROM products
WHERE stock_quantity < 10
ORDER BY stock_quantity ASC;

	
	
--highest-selling product category.

SELECT p.category, SUM(oi.quantity * oi.price) AS total_sales
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY total_sales DESC
LIMIT 1;
	
--all orders along with customer and product details.

select o.order_id,u.user_id,f.product_id,p.category,p.product_name from users u
INNER JOIN orders o
ON u.user_id=o.user_id
INNER JOIN order_items f
ON o.order_id = f.order_id
INNER JOIN products p
ON f.product_id=p.product_id
order by u.user_id

	SELECT 
    o.order_id, 
    o.order_date, 
    u.user_id, 
    u.username, 
    p.product_id, 
    p.product_name, 
    oi.quantity, 
    oi.price, 
    (oi.quantity * oi.price) AS total_amount
FROM orders o
JOIN users u ON o.user_id = u.user_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
ORDER BY o.order_id;

--Supplier-wise Product Listing
	--Showing which products are supplied by each supplier:
SELECT s.supplier_id, s.name AS supplier_name, p.product_id, p.product_name
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
ORDER BY s.name, p.product_name;

--Display the total sales per supplier
SELECT 
    s.supplier_id, 
    s.name AS supplier_name, 
    SUM(oi.quantity * oi.price) AS total_sales
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY s.supplier_id, s.name
ORDER BY total_sales DESC;


--products that have never been ordered.
select p.product_name,p.category
from products p
where p.product_id not in (select o.product_id from order_items o)

--the average order amount for each customer
SELECT 
    u.user_id, 
    u.username, 
    AVG(order_total.total_amount) AS average_order_amount
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN (
    SELECT 
        oi.order_id, 
        SUM(oi.quantity * oi.price) AS total_amount
    FROM order_items oi
    GROUP BY oi.order_id
) order_total ON o.order_id = order_total.order_id
GROUP BY u.user_id, u.username
ORDER BY average_order_amount DESC;


--customers who have spent more than the average customer.
SELECT a.user_id,a.total_spend from (select sum(oi.quantity*oi.price) as total_spend,u.user_id from users u
JOIN orders o ON o.user_id = u.user_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY u.user_id ORDER BY sum(oi.quantity*oi.price))a
	WHERE a.total_spend >
(SELECT AVG(b.total_spend) from (select sum(oi.quantity*oi.price) as total_spend,u.user_id from users u
JOIN orders o ON o.user_id = u.user_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY u.user_id ORDER BY sum(oi.quantity*oi.price))b)


--Rank products by total sales within each category
	select b.product_name,b.category, rank() over(partition by b.category order by b.total_sale desc) from
(select p.product_name,category,sum(oi.quantity*oi.price) as total_sale from order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_name,p.category,oi.product_id
order by category,sum(oi.quantity*oi.price) desc)b
	
-- the running total of sales by date
SELECT 
    o.order_date, 
    SUM(oi.quantity * oi.price) AS daily_sales,
    SUM(SUM(oi.quantity * oi.price)) OVER (ORDER BY o.order_date) AS running_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_date
ORDER BY o.order_date;
	--alternatively
select b.order_date,b.daily_sales,sum(b.daily_sales) over(order by b.order_date) as running_total from
(select sum(oi.quantity*oi.price) as daily_sales,order_date from order_items oi
JOIN orders ON orders.order_id = oi.order_id
GROUP BY order_date order by order_date)b

--top 3 highest-spending customers
SELECT 
    u.user_id, 
    u.username,
    SUM(oi.quantity * oi.price) AS total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY u.user_id, u.username
ORDER BY total_spent DESC
LIMIT 3;

--Add a new product and link it to an existing supplier
INSERT INTO products(product_id,product_name,category,price,stock_quantity,supplier_id)
VALUES (121,'Mouse','Electronics',750,23,1)

	
--Deleting orders that were canceled
DELETE from orders
where order_id is null
	
	
-- a function to update inventory after an order is placed
CREATE OR REPLACE FUNCTION update_stock_after_order(p_order_id INT)
RETURNS VOID AS $$
DECLARE
    product_id INT;
    ordered_quantity INT;
BEGIN
    -- Looping through each product in the order
    FOR product_id, ordered_quantity IN
        SELECT oi.product_id, oi.quantity
        FROM order_items oi
        WHERE oi.order_id = p_order_id
    LOOP
        -- Checking if there is sufficient stock
        IF (SELECT stock_quantity FROM products WHERE product_id = product_id) < ordered_quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product_id: %', product_id;
        END IF;

        -- Updating the stock quantity
        UPDATE products
        SET stock_quantity = stock_quantity - ordered_quantity
        WHERE product_id = product_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

	--usage
select update_stock_after_order(21);


--function  to insert new customers
CREATE OR REPLACE FUNCTION add_new_customer(
    p_name TEXT,
    p_email TEXT
)
RETURNS VOID AS $$
BEGIN
    -- Check if a customer with the same contact info already exists
    IF EXISTS (
        SELECT 1
        FROM users
        WHERE username = p_name
    ) THEN
        RAISE NOTICE 'Customer with username % already exists.', p_name;
    ELSE
        -- Insert a new customer record
        INSERT INTO users (username, email)
        VALUES (p_name, p_email);

        RAISE NOTICE 'New customer % added successfully.', p_name;
    END IF;
END;
$$ LANGUAGE plpgsql;
	--usage
SELECT add_new_customer('John Roy', 'tosh.doe@yahoo.com');


--a function to generate sales report
CREATE OR REPLACE FUNCTION generate_sales_report(
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE(
    report_date DATE,
    total_sales NUMERIC,
    total_orders INT,
    average_order_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CURRENT_DATE AS report_date,
        SUM(od.quantity * p.price) AS total_sales,
        COUNT(DISTINCT o.order_id) AS total_orders,
        AVG(od.quantity * p.price) AS average_order_value
    FROM 
        orders o
    JOIN 
        order_items oi ON o.order_id = oi.order_id
    JOIN 
        products p ON oi.product_id = p.product_id
    WHERE 
        o.order_date BETWEEN p_start_date AND p_end_date
    GROUP BY 
        CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;
	--usage
SELECT * FROM generate_sales_report('2024-01-01', '2024-12-31');

	
--A view to show active products (products with stock > 0)
CREATE VIEW ActiveProducts AS
SELECT 
    product_id, 
    product_name, 
    category, 
    price, 
    stock_quantity, 
    supplier_id
FROM products
WHERE stock_quantity > 0;

--Indexing frequently queried columns to improve performance.
	--1. Index on product_name for searching products:
CREATE INDEX idx_product_name ON products(product_name);


