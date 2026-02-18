package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.BlockedSite;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface BlockedSiteRepository extends JpaRepository<BlockedSite, Long> {
    List<BlockedSite> findByDeviceId(String deviceId);

    List<BlockedSite> findByDeviceIdIsNull();

    // Find global blocks + specific blocks for a device
    @org.springframework.data.jpa.repository.Query("SELECT b FROM BlockedSite b WHERE b.deviceId IS NULL OR b.deviceId = :deviceId")
    List<BlockedSite> findByDeviceIdOrGlobal(
            @org.springframework.data.repository.query.Param("deviceId") String deviceId);
}
