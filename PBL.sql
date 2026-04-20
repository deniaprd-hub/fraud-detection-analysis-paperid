

WITH ordered_transactions AS (
    SELECT transaction_amount, buyer_id, seller_id
    FROM payment_transaction
    ORDER BY transaction_amount
)
SELECT buyer_id, seller_id, transaction_amount
FROM ordered_transactions
WHERE transaction_amount > (
    SELECT transaction_amount
    FROM ordered_transactions
    WHERE buyer_id = ordered_transactions.buyer_id
    AND seller_id = ordered_transactions.seller_id
    LIMIT 1 OFFSET (SELECT ROUND(COUNT(*) * 0.75) FROM ordered_transactions)
) + 1.5 * (
    SELECT transaction_amount
    FROM ordered_transactions
    WHERE buyer_id = ordered_transactions.buyer_id
    AND seller_id = ordered_transactions.seller_id
    LIMIT 1 OFFSET (SELECT ROUND(COUNT(*) * 0.25) FROM ordered_transactions)
)
OR transaction_amount < (
    SELECT transaction_amount
    FROM ordered_transactions
    WHERE buyer_id = ordered_transactions.buyer_id
    AND seller_id = ordered_transactions.seller_id
    LIMIT 1 OFFSET (SELECT ROUND(COUNT(*) * 0.25) FROM ordered_transactions)
) - 1.5 * (
    SELECT transaction_amount
    FROM ordered_transactions
    WHERE buyer_id = ordered_transactions.buyer_id
    AND seller_id = ordered_transactions.seller_id
    LIMIT 1 OFFSET (SELECT ROUND(COUNT(*) * 0.75) FROM ordered_transactions)
);


--Analisis Hubungan Pembeli-Penjual 

SELECT buyer_id, seller_id, COUNT(*) AS transaction_count
FROM payment_transaction
GROUP BY buyer_id, seller_id
HAVING COUNT(*) > 50;  -- Menyesuaikan jumlah transaksi yang dianggap tinggi


--Deteksi Penyalahgunaan Promosi

SELECT 
    buyer_id, 
    dpt_promotion_id, 
    COUNT(*) AS promo_usage_count,
    MIN(transaction_date) AS first_promo_usage_date,  -- Tanggal penggunaan promo pertama
    MAX(transaction_date) AS last_promo_usage_date   -- Tanggal penggunaan promo terakhir
FROM payment_transaction pt 
WHERE dpt_promotion_id !='Unknown'
GROUP BY buyer_id, dpt_promotion_id
HAVING COUNT(*) > 1;   -- Menyesuaikan jumlah penggunaan promo yang dianggap berlebihan

--Waktu yang Mencurigakan
WITH transaction_diff AS (
    SELECT 
        buyer_id, 
        seller_id, 
        transaction_date,
        julianday(transaction_date) - julianday(LAG(transaction_date) OVER (PARTITION BY buyer_id ORDER BY transaction_date)) AS time_diff
    FROM payment_transaction
)
SELECT 
    buyer_id, 
    seller_id, 
    transaction_date,
    time_diff
FROM transaction_diff
WHERE time_diff * 1440 < 1  -- Waktu kurang dari 2 menit antar transaksi
ORDER BY transaction_date;

--SQL Bergabung untuk Wawasan Penipuan Pengguna-Perusahaan 
SELECT pt.buyer_id, pt.seller_id, c.company_id, c.company_kyc_status_name, COUNT(*) AS transaction_count
FROM payment_transaction pt 
JOIN company c ON pt.seller_id = c.company_id
WHERE c.company_kyc_status_name != 'VALIDASI_BERHASIL'
GROUP BY pt.buyer_id
HAVING COUNT(*) > 5;


--Pasangan Pembeli-Penjual Penipuan Teratas 
SELECT 
    buyer_id, 
    seller_id, 
    COUNT(*) AS transaction_count, 
    SUM(transaction_amount) AS total_amount
FROM payment_transaction pt 
JOIN company c ON pt.seller_id = c.company_id
WHERE c.user_fraud_flag == 1
GROUP BY buyer_id, seller_id
HAVING COUNT(*) > 50 AND SUM(transaction_amount) > 10000
ORDER BY transaction_count DESC ;

--Pengguna yang Ditandai dan Transaksinya
SELECT pt.buyer_id, pt.seller_id, pt.transaction_amount, pt.transaction_date 
FROM payment_transaction pt
JOIN company c  ON pt.buyer_id = c.company_id 
WHERE c.user_fraud_flag = '1'; 

--Prosedur Laporan Penipuan Bulanan
SELECT 
	COUNT(*) AS total_fraud,
	COUNT(DISTINCT buyer_id) AS total_pengguna_yang_ditandai,
	COUNT(DISTINCT buyer_id || '-' || seller_id) AS suspicious_transactions
FROM payment_transaction pt
JOIN company c ON pt.buyer_id = c.company_id 
WHERE user_fraud_flag = '1';

--Deteksi Penyalahgunaan Promosi Otomatis 
SELECT 
    buyer_id, 
    dpt_promotion_id, 
    COUNT(*) AS abuse_count
FROM payment_transaction pt
WHERE dpt_promotion_id !='Unknown'
GROUP BY buyer_id, dpt_promotion_id
HAVING COUNT(*) > 2
ORDER BY abuse_count DESC ;
