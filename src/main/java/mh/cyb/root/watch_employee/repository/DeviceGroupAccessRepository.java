package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.DeviceGroupAccess;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface DeviceGroupAccessRepository extends JpaRepository<DeviceGroupAccess, Long> {

    List<DeviceGroupAccess> findByGroupId(Long groupId);

    List<DeviceGroupAccess> findByDeviceId(String deviceId);

    @Query("SELECT a FROM DeviceGroupAccess a WHERE a.group.id = :groupId AND a.deviceId = :deviceId")
    DeviceGroupAccess findByGroupIdAndDeviceId(@Param("groupId") Long groupId,
            @Param("deviceId") String deviceId);

    @Modifying
    @Query("DELETE FROM DeviceGroupAccess a WHERE a.group.id = :groupId")
    void deleteByGroupId(@Param("groupId") Long groupId);

    @Query("SELECT COUNT(a) FROM DeviceGroupAccess a WHERE a.group.id = :groupId")
    long countByGroupId(@Param("groupId") Long groupId);
}
