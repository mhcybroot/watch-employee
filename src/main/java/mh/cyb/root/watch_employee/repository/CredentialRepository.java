package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.Credential;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CredentialRepository extends JpaRepository<Credential, Long> {
    List<Credential> findBySubmittedByDeviceId(String deviceId);

    List<Credential> findBySubmittedByDeviceIdIsNotNull();

    List<Credential> findBySubmittedByDeviceIdIsNull();
}
