-- Overall average ROP
SELECT 
    AVG(rop_m_per_hr) as avg_rop,
    MIN(rop_m_per_hr) as min_rop,
    MAX(rop_m_per_hr) as max_rop,
    STDEV(rop_m_per_hr) as std_dev_rop
FROM fact_drilling_operations
WHERE rop_m_per_hr IS NOT NULL AND rop_m_per_hr > 0;

-- ROP by well type
SELECT 
    w.well_type,
    AVG(f.rop_m_per_hr) as avg_rop,
    COUNT(*) as total_operations
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rop_m_per_hr IS NOT NULL
GROUP BY w.well_type
ORDER BY avg_rop DESC;

-- ROP by formation type (requires joining with dim_drilling_parameters)
SELECT 
    w.field_name,
    AVG(f.rop_m_per_hr) as avg_rop
    
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rop_m_per_hr IS NOT NULL
GROUP BY w.field_name
ORDER BY avg_rop DESC;


-- Overall cost per meter
SELECT 
    SUM(drilling_cost_usd) as total_cost,
    SUM(depth_m) as total_depth,
    CAST(SUM(drilling_cost_usd) / NULLIF(SUM(depth_m), 0) AS DECIMAL(10,2)) as cost_per_meter
FROM fact_drilling_operations
WHERE depth_m > 0;

-- Cost per meter by well
SELECT 
    w.well_name,
    w.field_name,
    SUM(f.drilling_cost_usd) as total_cost,
    MAX(f.depth_m) as max_depth,
    CAST(SUM(f.drilling_cost_usd) / NULLIF(MAX(f.depth_m), 0) AS DECIMAL(10,2)) as cost_per_meter
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.well_name, w.field_name
ORDER BY cost_per_meter DESC;

-- Cost per meter by rig type
SELECT 
    r.rig_type,
    r.automation_level,
    CAST(SUM(f.drilling_cost_usd) / NULLIF(SUM(f.depth_m), 0) AS DECIMAL(10,2)) as cost_per_meter
FROM fact_drilling_operations f
JOIN dim_rig r ON f.rig_id = r.rig_id
WHERE f.depth_m > 0
GROUP BY r.rig_type, r.automation_level
ORDER BY cost_per_meter;

-- Overall NPT percentage
SELECT 
    COUNT(*) as total_operations,
    SUM(CASE WHEN is_npt_flag = 1 THEN 1 ELSE 0 END) as npt_operations,
    CAST(SUM(CASE WHEN is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as npt_percentage
FROM fact_drilling_operations;

-- NPT by well
SELECT 
    w.well_name,
    w.field_name,
    COUNT(*) as total_operations,
    SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) as npt_count,
    CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as npt_pct
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.well_name, w.field_name
ORDER BY npt_pct DESC;

-- NPT by rig
SELECT 
    r.rig_name,
    r.rig_type,
    CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as npt_pct
FROM fact_drilling_operations f
JOIN dim_rig r ON f.rig_id = r.rig_id
GROUP BY r.rig_name, r.rig_type
ORDER BY npt_pct DESC;

-- Efficiency Index = (Actual ROP / Optimal ROP) * (1 - NPT%)
-- Using MSE as proxy for efficiency
SELECT 
    w.well_name,
    AVG(f.rop_m_per_hr) as avg_rop,
    AVG(f.mechanical_specific_energy) as avg_mse,
    CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as npt_pct,
    CAST((AVG(f.rop_m_per_hr) / NULLIF(AVG(f.mechanical_specific_energy), 0)) * (100 - CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))) AS DECIMAL(10,2)) as efficiency_index
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rop_m_per_hr > 0 AND f.mechanical_specific_energy > 0
GROUP BY w.well_name
ORDER BY efficiency_index DESC;

-- Calculate total available hours vs productive hours
WITH rig_hours AS (
    SELECT 
        rig_id,
        COUNT(*) as total_hours,
        COUNT(*) - SUM(CASE WHEN is_npt_flag = 1 THEN 1 ELSE 0 END) as productive_hours
    FROM fact_drilling_operations
    GROUP BY rig_id
)
SELECT 
    r.rig_name,
    r.rig_type,
    rh.total_hours,
    rh.productive_hours,
    CAST(rh.productive_hours * 100.0 / rh.total_hours AS DECIMAL(5,2)) as utilization_pct
FROM rig_hours rh
JOIN dim_rig r ON rh.rig_id = r.rig_id
ORDER BY utilization_pct DESC;

-- Monthly rig utilization
SELECT 
    r.rig_name,
    t.year,
    t.month,
    COUNT(*) as total_hours,
    CAST((COUNT(*) - SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END)) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as utilization_pct
FROM fact_drilling_operations f
JOIN dim_rig r ON f.rig_id = r.rig_id
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY r.rig_name, t.year, t.month
ORDER BY t.year, t.month, utilization_pct DESC;


-- ROP by Well
SELECT 
    w.well_name,
    w.well_type,
    w.field_name,
    AVG(f.rop_m_per_hr) as avg_rop,
    MIN(f.rop_m_per_hr) as min_rop,
    MAX(f.rop_m_per_hr) as max_rop,
    COUNT(*) as operations_count
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rop_m_per_hr > 0
GROUP BY w.well_name, w.well_type, w.field_name
ORDER BY avg_rop DESC;

-- ROP by Rig
SELECT 
    r.rig_name,
    r.rig_type,
    r.automation_level,
    AVG(f.rop_m_per_hr) as avg_rop,
    STDEV(f.rop_m_per_hr) as rop_std_dev
FROM fact_drilling_operations f
JOIN dim_rig r ON f.rig_id = r.rig_id
WHERE f.rop_m_per_hr > 0
GROUP BY r.rig_name, r.rig_type, r.automation_level
ORDER BY avg_rop DESC;

-- ROP performance across depth intervals
SELECT 
    CASE 
        WHEN depth_m < 1000 THEN '0-1000m'
        WHEN depth_m < 2000 THEN '1000-2000m'
        WHEN depth_m < 3000 THEN '2000-3000m'
        WHEN depth_m < 4000 THEN '3000-4000m'
        ELSE '4000m+'
    END as depth_interval,
    AVG(rop_m_per_hr) as avg_rop,
    COUNT(*) as operation_count
FROM fact_drilling_operations
WHERE rop_m_per_hr > 0
GROUP BY 
    CASE 
        WHEN depth_m < 1000 THEN '0-1000m'
        WHEN depth_m < 2000 THEN '1000-2000m'
        WHEN depth_m < 3000 THEN '2000-3000m'
        WHEN depth_m < 4000 THEN '3000-4000m'
        ELSE '4000m+'
    END
ORDER BY 
    CASE 
        WHEN depth_m < 1000 THEN 1
        WHEN depth_m < 2000 THEN 2
        WHEN depth_m < 3000 THEN 3
        WHEN depth_m < 4000 THEN 4
        ELSE 5
    END;

-- ROP trend by well with depth progression
SELECT 
    w.well_name,
    f.depth_m,
    f.rop_m_per_hr,
    AVG(f.rop_m_per_hr) OVER (
        PARTITION BY f.well_id 
        ORDER BY f.depth_m 
        ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
    ) as rolling_avg_rop
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rop_m_per_hr > 0
ORDER BY w.well_name, f.depth_m;


-- MSE deviation from optimal (assuming optimal MSE from parameters table)
WITH mse_stats AS (
    SELECT 
        AVG(mechanical_specific_energy) as avg_mse,
        STDEV(mechanical_specific_energy) as std_mse
    FROM fact_drilling_operations
    WHERE mechanical_specific_energy > 0
)
SELECT 
    w.well_name,
    AVG(f.mechanical_specific_energy) as avg_mse,
    s.avg_mse as overall_avg_mse,
    CAST((AVG(f.mechanical_specific_energy) - s.avg_mse) * 100.0 / s.avg_mse AS DECIMAL(5,2)) as mse_deviation_pct
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
CROSS JOIN mse_stats s
WHERE f.mechanical_specific_energy > 0
GROUP BY w.well_name, s.avg_mse
ORDER BY mse_deviation_pct DESC;

-- MSE efficiency (lower is better)
SELECT 
    r.rig_name,
    AVG(f.mechanical_specific_energy) as avg_mse,
    AVG(f.rop_m_per_hr) as avg_rop,
    CAST(AVG(f.mechanical_specific_energy) / NULLIF(AVG(f.rop_m_per_hr), 0) AS DECIMAL(10,2)) as mse_per_rop_ratio
FROM fact_drilling_operations f
JOIN dim_rig r ON f.rig_id = r.rig_id
WHERE f.mechanical_specific_energy > 0 AND f.rop_m_per_hr > 0
GROUP BY r.rig_name
ORDER BY mse_per_rop_ratio;

-- RPM and WOB coefficient of variation (CV = std dev / mean)
SELECT 
    w.well_name,
    AVG(f.rpm) as avg_rpm,
    STDEV(f.rpm) as std_rpm,
    CAST(STDEV(f.rpm) / NULLIF(AVG(f.rpm), 0) * 100 AS DECIMAL(5,2)) as rpm_cv_pct,
    AVG(f.wob_klbf) as avg_wob,
    STDEV(f.wob_klbf) as std_wob,
    CAST(STDEV(f.wob_klbf) / NULLIF(AVG(f.wob_klbf), 0) * 100 AS DECIMAL(5,2)) as wob_cv_pct
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.rpm > 0 AND f.wob_klbf > 0
GROUP BY w.well_name


-- Current depth progress vs target
SELECT 
    w.well_name,
    w.target_depth_m,
    MAX(f.depth_m) as current_depth,
    w.target_depth_m - MAX(f.depth_m) as remaining_depth,
    CAST(MAX(f.depth_m) * 100.0 / w.target_depth_m AS DECIMAL(5,2)) as completion_pct,
    w.spud_date,
    DATEDIFF(day, w.spud_date, MAX(t.date)) as days_drilling,
    CAST(MAX(f.depth_m) / NULLIF(DATEDIFF(day, w.spud_date, MAX(t.date)), 0) AS DECIMAL(10,2)) as avg_depth_per_day
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY w.well_name, w.target_depth_m, w.spud_date
ORDER BY completion_pct DESC;

-- Daily depth progress
SELECT 
    w.well_name,
    t.date,
    MAX(f.depth_m) as max_depth_day,
    MAX(f.depth_m) - LAG(MAX(f.depth_m)) OVER (PARTITION BY w.well_name ORDER BY t.date) as daily_progress
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY w.well_name, t.date
ORDER BY w.well_name, t.date;

-- Total cost by well
SELECT 
    w.well_name,
    w.field_name,
    SUM(f.drilling_cost_usd) as total_cost,
    MAX(f.depth_m) as final_depth,
    COUNT(*) as total_hours
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.well_name, w.field_name
ORDER BY total_cost DESC;

-- Total cost by operator
SELECT 
    w.operator,
    COUNT(DISTINCT w.well_id) as well_count,
    SUM(f.drilling_cost_usd) as total_cost,
    AVG(f.drilling_cost_usd) as avg_cost_per_hour
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.operator
ORDER BY total_cost DESC;

-- NPT cost analysis
SELECT 
    SUM(CASE WHEN is_npt_flag = 1 THEN drilling_cost_usd ELSE 0 END) as total_npt_cost,
    SUM(CASE WHEN is_npt_flag = 0 THEN drilling_cost_usd ELSE 0 END) as productive_cost,
    SUM(drilling_cost_usd) as total_cost,
    CAST(SUM(CASE WHEN is_npt_flag = 1 THEN drilling_cost_usd ELSE 0 END) * 100.0 / SUM(drilling_cost_usd) AS DECIMAL(5,2)) as npt_cost_pct
FROM fact_drilling_operations;

-- NPT cost by well
SELECT 
    w.well_name,
    SUM(CASE WHEN f.is_npt_flag = 1 THEN f.drilling_cost_usd ELSE 0 END) as npt_cost,
    SUM(f.drilling_cost_usd) as total_cost,
    CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN f.drilling_cost_usd ELSE 0 END) * 100.0 / SUM(f.drilling_cost_usd) AS DECIMAL(5,2)) as npt_cost_pct
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.well_name
ORDER BY npt_cost DESC;

-- Total NPT hours
SELECT 
    COUNT(*) as total_operations,
    SUM(CASE WHEN is_npt_flag = 1 THEN 1 ELSE 0 END) as npt_hours,
    SUM(CASE WHEN is_npt_flag = 0 THEN 1 ELSE 0 END) as productive_hours
FROM fact_drilling_operations;

-- NPT hours by month
SELECT 
    t.year,
    t.month,
    SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) as npt_hours,
    COUNT(*) as total_hours,
    CAST(SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as npt_pct
FROM fact_drilling_operations f
JOIN dim_time t ON f.time_id = t.time_id
GROUP BY t.year, t.month
ORDER BY t.year, t.month;

-- NPT hours by well and cause (requires anomaly linkage)
SELECT 
    w.well_name,
    SUM(CASE WHEN f.is_npt_flag = 1 THEN 1 ELSE 0 END) as npt_hours,
    COUNT(*) as total_hours
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
GROUP BY w.well_name
ORDER BY npt_hours DESC;


