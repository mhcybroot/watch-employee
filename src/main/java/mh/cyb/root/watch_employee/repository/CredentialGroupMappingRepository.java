package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.CredentialGroupMapping;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CredentialGroupMappingRepository extends JpaRepository<CredentialGroupMapping, Long> {

        List<CredentialGroupMapping> findByGroupId(Long groupId);

        List<CredentialGroupMapping> findByCredentialId(Long credentialId);

        @Query("SELECT m FROM CredentialGroupMapping m WHERE m.group.id = :groupId AND m.credential.id = :credentialId")
        CredentialGroupMapping findByGroupIdAndCredentialId(@Param("groupId") Long groupId,
                        @Param("credentialId") Long credentialId);

        @Modifying
        @Query("DELETE FROM CredentialGroupMapping m WHERE m.group.id = :groupId")
        void deleteByGroupId(@Param("groupId") Long groupId);

        @Modifying
        @Query("DELETE FROM CredentialGroupMapping m WHERE m.credential.id = :credentialId")
        void deleteByCredentialId(@Param("credentialId") Long credentialId);

        @Query("SELECT DISTINCT m.credential FROM CredentialGroupMapping m " +
                        "JOIN DeviceGroupAccess a ON a.group.id = m.group.id " +
                        "WHERE a.deviceId = :deviceId")
        List<mh.cyb.root.watch_employee.entity.Credential> findCredentialsAccessibleByDevice(
                        @Param("deviceId") String deviceId);

        @Query("SELECT COUNT(m) > 0 FROM CredentialGroupMapping m " +
                        "JOIN DeviceGroupAccess a ON a.group.id = m.group.id " +
                        "WHERE m.credential.id = :credentialId AND a.deviceId = :deviceId")
        boolean hasDeviceAccessToCredential(@Param("credentialId") Long credentialId,
                        @Param("deviceId") String deviceId);

        @Query("SELECT COUNT(m) FROM CredentialGroupMapping m WHERE m.group.id = :groupId")
        long countByGroupId(@Param("groupId") Long groupId);
}
