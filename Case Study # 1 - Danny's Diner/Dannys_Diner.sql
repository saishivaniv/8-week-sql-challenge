use dannys_diner;
CREATE  TABLE sales ( 
         customer_id VARCHAR(1), 
         order_date DATE, 
         product_id INT
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
  
  CREATE TABLE menu (
   product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  
  CREATE TABLE members (
   customer_id VARCHAR(1),
   join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
  SELECT * FROM sales;
  SELECT * FROM menu;
  SELECT * FROM members;
  
  -- What is the total amount each customer spent at the restaurant?
  SELECT s.customer_id, sum(m.price) AS total FROM sales s
  INNER JOIN menu m
  ON s.product_id = m.product_id
  GROUP BY s.customer_id;
  
  -- How many days has each customer visited the restaurant?
  SELECT s.customer_id, count(DISTINCT(s.order_date)) AS days FROM sales s 
  GROUP BY s.customer_id;
  
  -- What was the first item from the menu purchased by each customer?
  SELECT DISTINCT(s.customer_id), m.product_name FROM sales s
  JOIN menu m
  ON s.product_id = m.product_id
  WHERE s.order_date = (SELECT min(order_date) FROM sales WHERE customer_id = s.customer_id);
  
  -- What is the most purchased item on the menu and how many times was it purchased by all customers?
  SELECT count(m.product_name) AS count, m.product_name FROM menu m JOIN sales s 
  ON s.product_id = m.product_id
  GROUP BY m.product_name
  ORDER BY count DESC 
  LIMIT 1;
  
  -- Which item was the most popular for each customer?
WITH popular AS
(
SELECT s.customer_id,m.product_name,
        COUNT(s.product_id) as count,
        DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS rnk
FROM menu m 
JOIN sales s 
ON s.product_id = m.product_id
GROUP BY s.customer_id, s.product_id, m.product_name
) 
SELECT customer_id, product_name, count
FROM popular
WHERE rnk = 1;
  
--  Which item was purchased first by the customer after they became a member?  
WITH processed_data AS 
(
	SELECT s.customer_id AS customer,
       menu.product_name AS product,
       m.join_date,
       s.order_date AS first_order_date,
       RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rn
FROM sales s
JOIN members m ON m.customer_id = s.customer_id
JOIN menu ON menu.product_id = s.product_id
WHERE s.order_date > m.join_date
)

SELECT customer, product, first_order_date
FROM processed_data
WHERE rn=1;  

-- Which item was purchased just before the customer became a member?
WITH processed_data AS
(
SELECT s.customer_id AS customer,m.join_date,
	menu.product_name AS product,
	s.order_date,
	RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rn
    FROM sales s
    JOIN members m 
    ON m.customer_id = s.customer_id
    JOIN menu ON menu.product_id = s.product_id
    WHERE s.order_date < m.join_date
)
SELECT DISTINCT customer,product FROM processed_data
WHERE rn=1


-- What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id,
       count(product_name) AS total_items,
       SUM(price) AS amount_spent
FROM menu AS m
INNER JOIN sales AS s ON m.product_id = s.product_id
INNER JOIN members AS mem ON mem.customer_id = s.customer_id
WHERE order_date < join_date
GROUP BY s.customer_id
ORDER BY customer_id;

-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id,
       SUM(CASE 
	   WHEN m.product_name = 'sushi' THEN 2*10*m.price 
           ELSE 10*m.price 
           END) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id

-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of Janu


WITH program_last_day_cte AS
  (SELECT join_date,
          DATE_ADD(join_date, INTERVAL 7 DAY) AS program_last_date,
          customer_id
   FROM members)
SELECT s.customer_id,
       SUM(CASE
               WHEN order_date BETWEEN join_date AND program_last_date THEN price*10*2
               WHEN order_date NOT BETWEEN join_date AND program_last_date
                    AND product_name = 'sushi' THEN price*10*2
               WHEN order_date NOT BETWEEN join_date AND program_last_date
                    AND product_name != 'sushi' THEN price*10
           END) AS customer_points
FROM menu AS m
INNER JOIN sales AS s ON m.product_id = s.product_id
INNER JOIN program_last_day_cte AS mem ON mem.customer_id = s.customer_id
AND order_date <='2021-01-31'
AND order_date >=join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;



-- bonus question 
-- Join All The Things

SELECT customer_id,
       order_date,
       product_name,
       price,
       IF(order_date >= join_date, 'Y', 'N') AS member
FROM members
RIGHT JOIN sales USING (customer_id)
INNER JOIN menu USING (product_id)
ORDER BY customer_id,
         order_date;
         
-- Rank All The Things
WITH data_table AS
  (SELECT customer_id,
          order_date,
          product_name,
          price,
          IF(order_date >= join_date, 'Y', 'N') AS member
   FROM members
   RIGHT JOIN sales USING (customer_id)
   INNER JOIN menu USING (product_id)
   ORDER BY customer_id,
            order_date)
SELECT *,
       IF(member='N', NULL, DENSE_RANK() OVER (PARTITION BY customer_id, member
                                               ORDER BY order_date)) AS ranking
FROM data_table;