-- Check missing critical fields in fact table
SELECT 
    COUNT(*) as total_records,
    COUNT(operation_id) as records_with_id,
    COUNT(well_id) as records_with_well,
    COUNT(rig_id) as records_with_rig,
    COUNT(time_id) as records_with_time,
    COUNT(depth_m) as records_with_depth,
    COUNT(rop_m_per_hr) as records_with_rop,
    COUNT(drilling_cost_usd) as records_with_cost
FROM fact_drilling_operations;

-- Identify records with NULL critical values
SELECT operation_id, well_id, rig_id, depth_m, rop_m_per_hr
FROM fact_drilling_operations
WHERE depth_m IS NULL 
   OR rop_m_per_hr IS NULL 
   OR drilling_cost_usd IS NULL;

-- Find duplicate operations
SELECT operation_id, COUNT(*) as duplicate_count
FROM fact_drilling_operations
GROUP BY operation_id
HAVING COUNT(*) > 1;

-- Check for duplicate time entries per well
SELECT well_id, time_id, COUNT(*) as count
FROM fact_drilling_operations
GROUP BY well_id, time_id
HAVING COUNT(*) > 1;

-- Check for negative or zero values where inappropriate
SELECT operation_id, depth_m, rop_m_per_hr, wob_klbf, drilling_cost_usd
FROM fact_drilling_operations
WHERE depth_m <= 0 
   OR rop_m_per_hr < 0 
   OR wob_klbf < 0 
   OR drilling_cost_usd < 0;

-- Check for unrealistic ROP values (e.g., > 200 m/hr)
SELECT operation_id, rop_m_per_hr, depth_m, well_id
FROM fact_drilling_operations
WHERE rop_m_per_hr > 200 OR rop_m_per_hr < 0;

-- Verify depth doesn't exceed target depth
SELECT 
    f.operation_id,
    f.depth_m,
    w.target_depth_m,
    f.depth_m - w.target_depth_m as depth_excess
FROM fact_drilling_operations f
JOIN dim_well w ON f.well_id = w.well_id
WHERE f.depth_m > w.target_depth_m * 1.1; -- Allow 10% tolerance

-- Check for orphaned foreign keys
SELECT COUNT(*) as orphan_wells
FROM fact_drilling_operations f
LEFT JOIN dim_well w ON f.well_id = w.well_id
WHERE w.well_id IS NULL;

SELECT COUNT(*) as orphan_rigs
FROM fact_drilling_operations f
LEFT JOIN dim_rig r ON f.rig_id = r.rig_id
WHERE r.rig_id IS NULL;


-- Statistical outliers for ROP
WITH rop_stats AS (
    SELECT 
        AVG(rop_m_per_hr) as mean_rop,
        STDEV(rop_m_per_hr) as std_rop
    FROM fact_drilling_operations
    WHERE rop_m_per_hr IS NOT NULL
)
SELECT 
    f.operation_id,
    f.rop_m_per_hr,
    s.mean_rop,
    ABS(f.rop_m_per_hr - s.mean_rop) / s.std_rop as z_score
FROM fact_drilling_operations f
CROSS JOIN rop_stats s
WHERE ABS(f.rop_m_per_hr - s.mean_rop) / s.std_rop > 3;

-- MSE outliers
SELECT operation_id, mechanical_specific_energy, depth_m
FROM fact_drilling_operations
WHERE mechanical_specific_energy > (
    SELECT AVG(mechanical_specific_energy) + 3 * STDEV(mechanical_specific_energy)
    FROM fact_drilling_operations
);