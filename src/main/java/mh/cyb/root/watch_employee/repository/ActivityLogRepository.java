package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.ActivityLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ActivityLogRepository extends JpaRepository<ActivityLog, Long> {
        @org.springframework.data.jpa.repository.Query("SELECT DISTINCT a.deviceId FROM ActivityLog a")
        java.util.List<String> findDistinctDeviceIds();

        @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(a.durationSeconds), 0) FROM ActivityLog a")
        long getTotalDurationSeconds();

        @org.springframework.data.jpa.repository.Query("SELECT COUNT(DISTINCT a.deviceId) FROM ActivityLog a WHERE a.startTime >= :startTime")
        long countActiveDevicesSince(
                        @org.springframework.data.repository.query.Param("startTime") java.time.LocalDateTime startTime);

        @org.springframework.data.jpa.repository.Query("SELECT new map(hour(a.startTime) as hour, SUM(a.durationSeconds) as totalDuration) FROM ActivityLog a GROUP BY hour(a.startTime)")
        java.util.List<java.util.Map<String, Object>> getActivityByHour();

        @org.springframework.data.jpa.repository.Query("SELECT new map(a.domain as domain, SUM(a.durationSeconds) as totalDuration) FROM ActivityLog a GROUP BY a.domain ORDER BY SUM(a.durationSeconds) DESC")
        java.util.List<java.util.Map<String, Object>> getTopDomains();

        @org.springframework.data.jpa.repository.Query("SELECT a FROM ActivityLog a WHERE " +
                        "(CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) AND " +
                        "(CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate)")
        org.springframework.data.domain.Page<ActivityLog> findGlobalFiltered(
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate,
                        org.springframework.data.domain.Pageable pageable);

        @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(a.durationSeconds), 0) FROM ActivityLog a WHERE "
                        +
                        "(CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) AND " +
                        "(CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate)")
        long getGlobalTotalDurationFiltered(
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate);

        @org.springframework.data.jpa.repository.Query("SELECT COUNT(DISTINCT a.deviceId) FROM ActivityLog a WHERE " +
                        "(CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) AND " +
                        "(CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate)")
        long countGlobalActiveDevicesFiltered(
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate);

        // --- Employee Activity Viewer queries ---

        @org.springframework.data.jpa.repository.Query("SELECT a FROM ActivityLog a WHERE a.deviceId = :deviceId " +
                        "AND (CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) " +
                        "AND (CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate) " +
                        "AND (CAST(:domain AS String) IS NULL OR a.domain = :domain)")
        org.springframework.data.domain.Page<ActivityLog> findByDeviceIdFiltered(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId,
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate,
                        @org.springframework.data.repository.query.Param("domain") String domain,
                        org.springframework.data.domain.Pageable pageable);

        @org.springframework.data.jpa.repository.Query("SELECT DISTINCT a.domain FROM ActivityLog a WHERE a.deviceId = :deviceId ORDER BY a.domain")
        java.util.List<String> findDistinctDomainsByDeviceId(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId);

        @org.springframework.data.jpa.repository.Query("SELECT COALESCE(SUM(a.durationSeconds), 0) FROM ActivityLog a WHERE a.deviceId = :deviceId "
                        +
                        "AND (CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) " +
                        "AND (CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate) " +
                        "AND (CAST(:domain AS String) IS NULL OR a.domain = :domain)")
        long getTotalDurationByDeviceIdFiltered(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId,
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate,
                        @org.springframework.data.repository.query.Param("domain") String domain);

        @org.springframework.data.jpa.repository.Query("SELECT COUNT(a) FROM ActivityLog a WHERE a.deviceId = :deviceId "
                        +
                        "AND (CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) " +
                        "AND (CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate) " +
                        "AND (CAST(:domain AS String) IS NULL OR a.domain = :domain)")
        long countByDeviceIdFiltered(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId,
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate,
                        @org.springframework.data.repository.query.Param("domain") String domain);

        @org.springframework.data.jpa.repository.Query("SELECT new map(a.domain as domain, SUM(a.durationSeconds) as totalDuration) "
                        +
                        "FROM ActivityLog a WHERE a.deviceId = :deviceId " +
                        "AND (CAST(:startDate AS LocalDateTime) IS NULL OR a.startTime >= :startDate) " +
                        "AND (CAST(:endDate AS LocalDateTime) IS NULL OR a.startTime <= :endDate) " +
                        "GROUP BY a.domain ORDER BY SUM(a.durationSeconds) DESC")
        java.util.List<java.util.Map<String, Object>> getDomainStatsByDeviceIdFiltered(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId,
                        @org.springframework.data.repository.query.Param("startDate") java.time.LocalDateTime startDate,
                        @org.springframework.data.repository.query.Param("endDate") java.time.LocalDateTime endDate);

        @org.springframework.data.jpa.repository.Query("SELECT MAX(a.startTime) FROM ActivityLog a WHERE a.deviceId = :deviceId")
        java.time.LocalDateTime findLastSeenByDeviceId(
                        @org.springframework.data.repository.query.Param("deviceId") String deviceId);
}
