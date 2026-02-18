package mh.cyb.root.watch_employee.repository;

import mh.cyb.root.watch_employee.entity.Credential;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CredentialRepository extends JpaRepository<Credential, Long> {
}
