SELECT  
--IDENTIFICATION:
	DB_NAME(ixO.database_id) AS database__name,
	O.name AS object__name,
	I.name AS index__name,
	I.type_desc AS index__type,
    ixO.index_id ,
    ixO.partition_number ,

--LEAF LEVEL ACTIVITY:
    ixO.leaf_insert_count ,
    ixO.leaf_delete_count ,
    ixO.leaf_update_count ,
	ixO.leaf_page_merge_count ,
    ixO.leaf_ghost_count ,

--NON-LEAF LEVEL ACTIVITY:
    ixO.nonleaf_insert_count ,
    ixO.nonleaf_delete_count ,
    ixO.nonleaf_update_count ,
    ixO.nonleaf_page_merge_count ,

--PAGE SPLIT COUNTS:
    ixO.leaf_allocation_count ,
    ixO.nonleaf_allocation_count ,	

--ACCESS ACTIVITY:
    ixO.range_scan_count ,
    ixO.singleton_lookup_count ,
    ixO.forwarded_fetch_count ,

--LOCKING ACTIVITY:
    ixO.row_lock_count ,
    ixO.row_lock_wait_count ,
    ixO.row_lock_wait_in_ms ,
    ixO.page_lock_count ,
    ixO.page_lock_wait_count ,
    ixO.page_lock_wait_in_ms ,
    ixO.index_lock_promotion_attempt_count ,
    ixO.index_lock_promotion_count ,

--LATCHING ACTIVITY:
    ixO.page_latch_wait_count ,
    ixO.page_latch_wait_in_ms ,
    ixO.page_io_latch_wait_count ,
    ixO.page_io_latch_wait_in_ms ,
    ixO.tree_page_latch_wait_count ,
    ixO.tree_page_latch_wait_in_ms ,
    ixO.tree_page_io_latch_wait_count ,
    ixO.tree_page_io_latch_wait_in_ms ,

--COMPRESSION ACTIVITY:
    ixO.page_compression_attempt_count ,
    ixO.page_compression_success_count 
FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ixO
	INNER JOIN sys.indexes I 
		ON ixO.object_id = I.object_id 
			AND ixO.index_id = I.index_id
	INNER JOIN sys.objects AS O
		ON O.object_id = ixO.object_id
WHERE O.is_ms_shipped = 0;