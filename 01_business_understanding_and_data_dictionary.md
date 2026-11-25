# E-Commerce 360 — Business Understanding & Data Dictionary

> Self-initiated end-to-end analytics case study on the Olist Brazilian E-Commerce public dataset (2016-09 to 2018-10). Stakeholders below are simulated to frame a realistic analyst brief; this is not a real client engagement.

## 1. Business problem

An e-commerce marketplace wants to understand its sales performance, customer behaviour, product and seller performance, delivery operations and customer satisfaction, so that management can identify business problems, opportunities and actionable improvements.

## 2. Stakeholders (simulated)

| Stakeholder | What they need to know |
|---|---|
| Head of Sales / Category Management | Which categories and regions drive revenue; how sales trend over time |
| Marketplace / Seller Management | Which sellers and products carry the business; how concentrated it is; which sellers cause problems |
| Logistics / Operations | How often deliveries are late; where and why |
| Customer Experience | What drives low review scores; how delivery affects satisfaction |
| Executive Leadership | One-page view of overall health |

## 3. Objectives

1. Measure overall sales performance and identify growth patterns.
2. Understand customer base size, geography and repeat behaviour.
3. Identify top and weak categories, products and sellers.
4. Quantify delivery performance and locate operational bottlenecks.
5. Understand what drives customer satisfaction, in particular the role of delivery.
6. Turn findings into evidence-based recommendations.

## 4. Business questions (what the analysis must answer)

| Area | Questions |
|---|---|
| Sales | How do revenue and orders trend by month? Which categories and states contribute most? What is the average order value? How do customers pay? |
| Customers | How many unique customers are there? What share order more than once? Where are customers located? |
| Product & Seller | Which categories earn the most? How concentrated is revenue among sellers? Which sellers combine high volume with poor reviews? |
| Delivery & Operations | What is the average delivery time? How does actual compare with estimated delivery? What is the late-delivery rate, and where is it highest (state, category, seller)? |
| Satisfaction | What is the average review score? Which categories and sellers score lowest? How does delivery delay relate to review score? |

Findings are decided only after calculation, never before.

## 5. Proposed KPI definitions (final rules are fixed and tested in Stage 2)

| KPI | Proposed definition | Watch-out found in Stage 1 |
|---|---|---|
| Revenue | Sum of `price` from `order_items` for the agreed order population | Never sum `payment_value` after joining to items (payments have several rows per order) |
| Orders | Count of distinct `order_id` | Joins to items multiply order rows |
| Customers | Count of distinct `customer_unique_id` | `customer_id` is created per order |
| AOV | Revenue / Orders | Same population for numerator and denominator |
| Average review score | Mean of one review per order | 547 orders have more than one review |
| On-time delivery % | Delivered orders with customer delivery date <= estimated date, divided by delivered orders that have a delivery date | 8 delivered orders have no delivery date |
| Late-delivery rate | 100% minus on-time delivery % | Same population as above |
| Delivery time | Days from purchase to customer delivery | 166 orders have carrier date before purchase; check before using carrier-based metrics |

## 6. Data dictionary

Column names are as in the source files (including source spelling such as `lenght`). Meanings come from the dataset documentation and were checked against the data in the Stage 1 notebook.

### customers — one row per `customer_id` (PK)
| Column | Meaning | Notes |
|---|---|---|
| customer_id | Customer key used in `orders` | Unique, created per order |
| customer_unique_id | Identifier of the actual person | Use for repeat-customer analysis |
| customer_zip_code_prefix | First 5 digits of customer ZIP | Links to geolocation (not unique there) |
| customer_city | Customer city | |
| customer_state | Customer state (2-letter code) | |

### orders — one row per `order_id` (PK)
| Column | Meaning | Notes |
|---|---|---|
| order_id | Order key | |
| customer_id | FK to customers | |
| order_status | delivered, shipped, canceled, unavailable, invoiced, processing, created, approved | Decides which orders count for sales and delivery KPIs |
| order_purchase_timestamp | When the customer placed the order | |
| order_approved_at | Payment approval time | 160 missing |
| order_delivered_carrier_date | When the order was handed to the logistics partner | 1,783 missing |
| order_delivered_customer_date | When the customer received the order | 2,965 missing |
| order_estimated_delivery_date | Delivery date promised to the customer | |

### order_items — one row per item in an order, PK (`order_id`, `order_item_id`)
| Column | Meaning | Notes |
|---|---|---|
| order_id | FK to orders | |
| order_item_id | Item sequence number within the order | |
| product_id | FK to products | |
| seller_id | FK to sellers | |
| shipping_limit_date | Seller's deadline to hand the item to the carrier | |
| price | Item price | Revenue source |
| freight_value | Shipping cost for the item | |

### products — one row per `product_id` (PK)
| Column | Meaning | Notes |
|---|---|---|
| product_id | Product key | |
| product_category_name | Category in Portuguese | 610 missing; links to category_translation |
| product_name_lenght | Characters in the product name | Source spelling kept; 610 missing |
| product_description_lenght | Characters in the product description | Source spelling kept; 610 missing |
| product_photos_qty | Number of photos | 610 missing |
| product_weight_g | Weight in grams | 2 missing |
| product_length_cm, product_height_cm, product_width_cm | Package dimensions | 2 missing each |

### sellers — one row per `seller_id` (PK)
| Column | Meaning | Notes |
|---|---|---|
| seller_id | Seller key | |
| seller_zip_code_prefix | Seller ZIP prefix | 7 prefixes absent from geolocation |
| seller_city, seller_state | Seller location | |

### payments — one row per payment record, PK (`order_id`, `payment_sequential`)
| Column | Meaning | Notes |
|---|---|---|
| order_id | FK to orders | An order can have up to 29 payment rows |
| payment_sequential | Order of payment methods used for the order | |
| payment_type | credit_card, boleto, voucher, debit_card, not_defined | 3 `not_defined` rows |
| payment_installments | Number of installments chosen | 2 rows with 0 |
| payment_value | Amount paid in this record | 9 rows with 0 |

### reviews — one row per review submission, PK (`review_id`, `order_id`)
| Column | Meaning | Notes |
|---|---|---|
| review_id | Review identifier | Not unique on its own (789 repeated ids) |
| order_id | FK to orders | 547 orders have more than one review |
| review_score | Satisfaction score 1 to 5 | |
| review_comment_title | Optional comment title | Mostly empty |
| review_comment_message | Optional comment text | About 59% empty |
| review_creation_date | Date the satisfaction survey was sent | |
| review_answer_timestamp | When the customer answered | |

### geolocation — many rows per ZIP prefix, no unique key
| Column | Meaning | Notes |
|---|---|---|
| geolocation_zip_code_prefix | ZIP prefix | 19,015 distinct values |
| geolocation_lat, geolocation_lng | Coordinates | 261,831 fully duplicated rows |
| geolocation_city, geolocation_state | City and state | 8,559 prefixes carry more than one label |

### category_translation — one row per Portuguese category, PK (`product_category_name`)
| Column | Meaning | Notes |
|---|---|---|
| product_category_name | Category in Portuguese | 71 rows; 2 product categories have no match |
| product_category_name_english | English category name | |

## 7. Dataset limitations

- Public historical data (2016-09 to 2018-10) from a Brazilian marketplace; it does not describe current performance.
- Customers are tracked per order id; true repeat behaviour is only visible through `customer_unique_id`.
- Only orders with item rows can carry revenue (775 orders have none).
- Findings describe association, not causation.
